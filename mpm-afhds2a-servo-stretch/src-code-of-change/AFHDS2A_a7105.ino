 /*
 This project is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.

 Multiprotocol is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with Multiprotocol.  If not, see <http://www.gnu.org/licenses/>.
 */
// Last sync with hexfet new_protocols/flysky_a7105.c dated 2015-09-28

#ifdef AFHDS2A_A7105_INO

#define AFHDS2A_TXPACKET_SIZE	38
#define AFHDS2A_RXPACKET_SIZE	37
#define AFHDS2A_NUMFREQ			16

#if not defined TELEMETRY
	uint8_t RX_LQI=0;
#endif

enum{
	AFHDS2A_PACKET_STICKS,
	AFHDS2A_PACKET_SETTINGS,
	AFHDS2A_PACKET_FAILSAFE,
};

enum{
	AFHDS2A_BIND1,
	AFHDS2A_BIND2,
	AFHDS2A_BIND3,
	AFHDS2A_BIND4,
	AFHDS2A_DATA_INIT,
	AFHDS2A_DATA,
};

static void AFHDS2A_calc_channels()
{
	uint8_t idx = 0;
	uint32_t rnd = MProtocol_id;
	while (idx < AFHDS2A_NUMFREQ)
	{
		uint8_t i;
		uint8_t band_no = ((((idx<<1) | ((idx>>1) & 0b01)) + rx_tx_addr[3]) & 0b11);
		rnd = rnd * 0x0019660D + 0x3C6EF35F; // Randomization

		uint8_t next_ch = band_no*41 + 1 + ((rnd >> idx) % 41); // Channel range: 1..164

		for (i = 0; i < idx; i++)
		{
			// Keep the distance 5 between the channels 
			uint8_t distance;
			if (next_ch > hopping_frequency[i])
				distance = next_ch - hopping_frequency[i];
			else
				distance = hopping_frequency[i] - next_ch;

			if (distance < 5) break;
		}

		if (i != idx) continue;

		hopping_frequency[idx++] = next_ch;
	}
}

// telemetry sensors ID
enum{
	AFHDS2A_SENSOR_RX_VOLTAGE   = 0x00,
	AFHDS2A_SENSOR_RX_ERR_RATE  = 0xfe,
	AFHDS2A_SENSOR_RX_RSSI      = 0xfc,
	AFHDS2A_SENSOR_RX_NOISE     = 0xfb,
	AFHDS2A_SENSOR_RX_SNR       = 0xfa,
	AFHDS2A_SENSOR_A3_VOLTAGE   = 0x03,
};

#if defined(AFHDS2A_FW_TELEMETRY) || defined(AFHDS2A_HUB_TELEMETRY)
static void AFHDS2A_update_telemetry()
{
	// Read TX RSSI
	int16_t temp=256-(A7105_ReadReg(A7105_1D_RSSI_THOLD)*8)/5;		// value from A7105 is between 8 for maximum signal strength to 160 or less
	if(temp<0) temp=0;
	else if(temp>255) temp=255;
	TX_RSSI=temp;
	// AA | TXID | rx_id | sensor id | sensor # | value 16 bit big endian | sensor id ......
	// AC | TXID | rx_id | sensor id | sensor # | length | bytes | sensor id ......
	#ifdef AFHDS2A_FW_TELEMETRY
		if (option & 0x80)
		{// forward 0xAA and 0xAC telemetry to TX, skip rx and tx id to save space
			packet_in[0]= TX_RSSI;
			debug("T(%02X)=",packet[0]);
			for(uint8_t i=9;i < AFHDS2A_RXPACKET_SIZE; i++)
			{
				packet_in[i-8]=packet[i];
				debug(" %02X",packet[i]);
			}
			packet_in[29]=packet[0];	// 0xAA Normal telemetry, 0xAC Extended telemetry
			telemetry_link=2;
			debugln("");
			return;
		}
	#endif
	#ifdef AFHDS2A_HUB_TELEMETRY
		if(packet[0]==0xAA)
		{ // 0xAA Normal telemetry, 0xAC Extended telemetry not decoded here
			for(uint8_t sensor=0; sensor<7; sensor++)
			{
				// Send FrSkyD telemetry to TX
				uint8_t index = 9+(4*sensor);
				switch(packet[index])
				{
					case AFHDS2A_SENSOR_RX_VOLTAGE:
						//v_lipo1 = packet[index+3]<<8 | packet[index+2];
						v_lipo1 = packet[index+2];
						telemetry_link=1;
						break;
					case AFHDS2A_SENSOR_A3_VOLTAGE:
						v_lipo2 = (packet[index+3]<<5) | (packet[index+2]>>3);	// allows to read voltage up to 4S
						telemetry_link=1;
						break;
					case AFHDS2A_SENSOR_RX_ERR_RATE:
						if(packet[index+2]<=100)
							RX_LQI=packet[index+2];
						break;
					case AFHDS2A_SENSOR_RX_RSSI:
						RX_RSSI = -packet[index+2];
						break;
					case 0xff: // end of data
						return;
					/*default:
						// unknown sensor ID
						break;*/
				}
			}
		}
	#endif
}
#endif

static void AFHDS2A_build_bind_packet()
{
	uint8_t ch;
	memcpy( &packet[1], rx_tx_addr, 4);
	memset( &packet[5], 0xff, 4);
	packet[10]= 0x00;
	for(ch=0; ch<AFHDS2A_NUMFREQ; ch++)
		packet[11+ch] = hopping_frequency[ch];
	memset( &packet[27], 0xff, 10);
	packet[37] = 0x00;
	switch(phase)
	{
		case AFHDS2A_BIND1:
			packet[0] = 0xbb;
			packet[9] = 0x01;
			break;
		case AFHDS2A_BIND2:
		case AFHDS2A_BIND3:
		case AFHDS2A_BIND4:
			packet[0] = 0xbc;
			if(phase == AFHDS2A_BIND4)
			{
				memcpy( &packet[5], &rx_id, 4);
				memset( &packet[11], 0xff, 16);
			}
			packet[9] = phase-1;
			if(packet[9] > 0x02)
				packet[9] = 0x02;
			packet[27]= 0x01;
			packet[28]= 0x80;
			break;
	}
}

#define ENABLE_SERVO_STRETCH

static void AFHDS2A_build_packet(uint8_t type)
{
	#ifdef ENABLE_SERVO_STRETCH
	static uint32_t stretch_channel = 0;
	#endif

	uint16_t val;
	memcpy( &packet[1], rx_tx_addr, 4);
	memcpy( &packet[5], rx_id, 4);
	switch(type)
	{
		case AFHDS2A_PACKET_STICKS:		
			packet[0] = 0x58;
			//16 channels + RX_LQI on channel 17
			for(uint8_t ch=0; ch<num_ch; ch++)
			{
				if(ch == 16 // CH17=RX_LQI
				#ifdef AFHDS2A_LQI_CH
					|| ch == (AFHDS2A_LQI_CH-1)	// override channel with LQI
				#endif
					)
					val = 2000 - 10*RX_LQI;
				else { // ch != 16
					uint16_t vv = convert_channel_ppm(CH_AETR[ch]);
					#ifdef ENABLE_SERVO_STRETCH
					if (vv > (1500 - 768 - 16) && (vv < (1500 - 512 - 16) || vv > (1500 + 512 + 16))) {
						stretch_channel |= 1 << ch;
					}
					if ((stretch_channel & (1 << ch)) != 0 && ch < 14) {
						val = map(vv, 1500 - 768, 1500 + 768, 1500 - 1500, 1500 + 1500);
					}
					else
					#endif
					{
						val = vv;
					}
				}
				if(ch<14)
				{
					packet[9 +  ch*2] = val;
					packet[10 + ch*2] = (val>>8)&0x0F;
				}
				else
				{
					packet[10 + (ch-14)*6] |= (val)<<4;
					packet[12 + (ch-14)*6] |= (val)&0xF0;
					packet[14 + (ch-14)*6] |= (val>>4)&0xF0;
				}
			}
			break;
		case AFHDS2A_PACKET_FAILSAFE:
			packet[0] = 0x56;
			for(uint8_t ch=0; ch<num_ch; ch++)
			{
				#ifdef FAILSAFE_ENABLE
					if(ch<16)
						val = Failsafe_data[CH_AETR[ch]];
					else
						val = FAILSAFE_CHANNEL_NOPULSES;
					if(val!=FAILSAFE_CHANNEL_HOLD && val!=FAILSAFE_CHANNEL_NOPULSES)
					{ // Failsafe values
						val = (((val<<2)+val)>>3)+860;
						if(ch<14)
						{
							packet[9 +  ch*2] = val;
							packet[10 + ch*2] = (val>>8)&0x0F;
						}
						else
						{
							packet[10 + (ch-14)*6] &= 0x0F;
							packet[10 + (ch-14)*6] |= (val)<<4;
							packet[12 + (ch-14)*6] &= 0x0F;
							packet[12 + (ch-14)*6] |= (val)&0xF0;
							packet[14 + (ch-14)*6] &= 0x0F;
							packet[14 + (ch-14)*6] |= (val>>4)&0xF0;
						}
					}
					else
				#endif
						if(ch<14)
						{ // no values
							packet[9 + ch*2] = 0xff;
							packet[10+ ch*2] = 0xff;
						}
			}
			break;
		case AFHDS2A_PACKET_SETTINGS:
			packet[0] = 0xaa;
			packet[9] = 0xfd;
			packet[10]= 0xff;
			val=5*(option & 0x7f)+50;	// option value should be between 0 and 70 which gives a value between 50 and 400Hz
			if(val<50 || val>400) val=50;	// default is 50Hz
			packet[11]= val;
			packet[12]= val >> 8;
			packet[13] = sub_protocol & 0x01;	// 1 -> PPM output enabled
			packet[14]= 0x00;
			for(uint8_t i=15; i<37; i++)
				packet[i] = 0xff;
			packet[18] = 0x05;		// ?
			packet[19] = 0xdc;		// ?
			packet[20] = 0x05;		// ?
			if(sub_protocol&2)
				packet[21] = 0xdd;	// SBUS output enabled
			else
				packet[21] = 0xde;	// IBUS
			break;
	}
	packet[37] = 0x00;
}

#define AFHDS2A_WAIT_WRITE 0x80

#ifdef STM32_BOARD
	#define AFHDS2A_WRITE_TIME 1550
#else
	#define AFHDS2A_WRITE_TIME 1700
#endif

uint16_t AFHDS2A_callback()
{
	static uint8_t packet_type;
	static uint16_t packet_counter;
	uint8_t data_rx=0;
	uint16_t start;
	#ifndef FORCE_AFHDS2A_TUNING
		A7105_AdjustLOBaseFreq(1);
	#endif
	switch(phase)
	{
		case AFHDS2A_BIND1:
		case AFHDS2A_BIND2:
		case AFHDS2A_BIND3:
			AFHDS2A_build_bind_packet();
			data_rx=A7105_ReadReg(A7105_00_MODE);			// Check if something has been received...
			A7105_WriteData(AFHDS2A_TXPACKET_SIZE, packet_count%2 ? 0x0d : 0x8c);
			if(!(A7105_ReadReg(A7105_00_MODE) & (1<<5)) && !(data_rx & 1))	// removed FECF check due to issues with fs-x6b ->  & (1<<5 | 1<<6)
			{ // RX+CRCF Ok
				A7105_ReadData(AFHDS2A_RXPACKET_SIZE);
				#if 0
					debug("RX");
					for(uint8_t i=0; i<AFHDS2A_RXPACKET_SIZE ; i++)
						debug(" %02X", packet[i]);
					debugln("");
				#endif
				if(packet[0] == 0xbc && packet[9] == 0x01)
				{
					uint16_t addr;
					if(RX_num<16)
						addr=AFHDS2A_EEPROM_OFFSET+RX_num*4;
					else
						addr=AFHDS2A_EEPROM_OFFSET2+(RX_num-16)*4;
					for(uint8_t i=0; i<4; i++)
					{
						rx_id[i] = packet[5+i];
						eeprom_write_byte((EE_ADDR)(addr+i),rx_id[i]);
					}
					phase = AFHDS2A_BIND4;
					packet_count++;
					break;
				}
			}
			packet_count++;
			if(IS_BIND_DONE)
			{ // exit bind if asked to do so from the GUI
				phase = AFHDS2A_BIND4;
				break;
			}
			phase |= AFHDS2A_WAIT_WRITE;
			return AFHDS2A_WRITE_TIME;
		case AFHDS2A_BIND1|AFHDS2A_WAIT_WRITE:
		case AFHDS2A_BIND2|AFHDS2A_WAIT_WRITE:
		case AFHDS2A_BIND3|AFHDS2A_WAIT_WRITE:
			//Wait for TX completion
			start=micros();
			while ((uint16_t)((uint16_t)micros()-start) < 700)			// Wait max 700µs, using serial+telemetry exit in about 120µs
				if(!(A7105_ReadReg(A7105_00_MODE) & 0x01))
					break;
			A7105_SetPower();
			A7105_SetTxRxMode((packet_count & 0x40) ? TXRX_OFF : RX_EN);	// Turn LNA off time to time since we are in near range and we want to prevent swamping
			A7105_Strobe(A7105_RX);
			phase &= ~AFHDS2A_WAIT_WRITE;
			phase++;
			if(phase > AFHDS2A_BIND3)
				phase = AFHDS2A_BIND1;
			return 3850-AFHDS2A_WRITE_TIME;
		case AFHDS2A_BIND4:
			AFHDS2A_build_bind_packet();
			A7105_WriteData(AFHDS2A_TXPACKET_SIZE, packet_count%2 ? 0x0d : 0x8c);
			packet_count++;
			bind_phase++;
			if(bind_phase>=4)
			{ 
				hopping_frequency_no=1;
				phase = AFHDS2A_DATA_INIT;
				BIND_DONE;
			}
			break;
		case AFHDS2A_DATA_INIT:
			packet_counter=0;
			packet_type = AFHDS2A_PACKET_STICKS;
			phase = AFHDS2A_DATA;
		case AFHDS2A_DATA:
			#ifdef MULTI_SYNC
				telemetry_set_input_sync(3850);
			#endif
			AFHDS2A_build_packet(packet_type);
			data_rx=A7105_ReadReg(A7105_00_MODE);			// Check if something has been received...
			A7105_WriteData(AFHDS2A_TXPACKET_SIZE, hopping_frequency[hopping_frequency_no++]);
			if(hopping_frequency_no >= AFHDS2A_NUMFREQ)
				hopping_frequency_no = 0;
			if(!(packet_counter % 1313))
				packet_type = AFHDS2A_PACKET_SETTINGS;
			else
			{
				#ifdef FAILSAFE_ENABLE
					if(!(packet_counter % 1569) && IS_FAILSAFE_VALUES_on)
					{
						packet_type = AFHDS2A_PACKET_FAILSAFE;
						FAILSAFE_VALUES_off;
					}
					else
				#endif
						packet_type = AFHDS2A_PACKET_STICKS;	// todo : check for settings changes
			}
			if(!(A7105_ReadReg(A7105_00_MODE) & (1<<5)) && !(data_rx & 1))	// removed FECF check due to issues with fs-x6b ->  & (1<<5 | 1<<6)
			{ // RX+CRCF Ok
				A7105_ReadData(AFHDS2A_RXPACKET_SIZE);
				if(packet[0] == 0xAA && packet[9] == 0xFC)
					packet_type=AFHDS2A_PACKET_SETTINGS;		// RX is asking for settings
				else
					if((packet[0] == 0xAA && packet[9]!=0xFD) || packet[0] == 0xAC)
					{// Normal telemetry packet, ignore packets which contain the RX configuration: AA FD FF 32 00 01 00 FF FF FF 05 DC 05 DE FA FF FF FF FF FF FF FF FF FF FF FF FF FF FF
						if(!memcmp(&packet[1], rx_tx_addr, 4))
						{ // TX address validated
							for(uint8_t sensor=0; sensor<7; sensor++)
							{//read LQI value for RX output
								uint8_t index = 9+(4*sensor);
								if(packet[index]==AFHDS2A_SENSOR_RX_ERR_RATE && packet[index+2]<=100)
								{
									RX_LQI=packet[index+2];
									break;
								}
							}
							#if defined(AFHDS2A_FW_TELEMETRY) || defined(AFHDS2A_HUB_TELEMETRY)
								AFHDS2A_update_telemetry();
							#endif
						}
					}
			}
			packet_counter++;
			phase |= AFHDS2A_WAIT_WRITE;
			return AFHDS2A_WRITE_TIME;
		case AFHDS2A_DATA|AFHDS2A_WAIT_WRITE:
			//Wait for TX completion
			start=micros();
			while ((uint16_t)((uint16_t)micros()-start) < 700)			// Wait max 700µs, using serial+telemetry exit in about 120µs
				if(!(A7105_ReadReg(A7105_00_MODE) & 0x01))
					break;
			A7105_SetPower();
			A7105_SetTxRxMode(RX_EN);
			A7105_Strobe(A7105_RX);
			phase &= ~AFHDS2A_WAIT_WRITE;
			return 3850-AFHDS2A_WRITE_TIME;
	}
	return 3850;
}

void AFHDS2A_init()
{
	A7105_Init();

	AFHDS2A_calc_channels();
	packet_count = 0;
	bind_phase = 0;
	if(IS_BIND_IN_PROGRESS)
		phase = AFHDS2A_BIND1;
	else
	{
		phase = AFHDS2A_DATA_INIT;
		//Read RX ID from EEPROM based on RX_num, RX_num must be uniq for each RX
		uint16_t addr;
		if(RX_num<16)
			addr=AFHDS2A_EEPROM_OFFSET+RX_num*4;
		else
			addr=AFHDS2A_EEPROM_OFFSET2+(RX_num-16)*4;
		for(uint8_t i=0;i<4;i++)
			rx_id[i]=eeprom_read_byte((EE_ADDR)(addr+i));
	}
	hopping_frequency_no = 0;
	if(sub_protocol&0x04)
		num_ch=17;
	else
		num_ch=14;
}
#endif
