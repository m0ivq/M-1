------------------------------------------------------------------------------
--                                                                          --
--                    SYSTEM M-1 MODULE MKTOGGLE                            --
--                                                                          --
--                                 M-1                                      --
--                                                                          --
--                               B o d y                                    --
--                                                                          --
--         Copyright (C) 2017 Mario Blunk, Blunk electronic                 --
--                                                                          --
--    This program is free software: you can redistribute it and/or modify  --
--    it under the terms of the GNU General Public License as published by  --
--    the Free Software Foundation, either version 3 of the License, or     --
--    (at your option) any later version.                                   --
--                                                                          --
--    This program is distributed in the hope that it will be useful,       --
--    but WITHOUT ANY WARRANTY; without even the implied warranty of        --
--    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         --
--    GNU General Public License for more details.                          --
--                                                                          --
--    You should have received a copy of the GNU General Public License     --
--    along with this program.  If not, see <http://www.gnu.org/licenses/>. --
------------------------------------------------------------------------------

--   Please send your questions and comments to:
--
--   info@blunk-electronic.de
--   or visit <http://www.blunk-electronic.de> for more contact data
--
--   history of changes:
--

-- todo: option/algorithm for reading back the target net


with ada.text_io;				use ada.text_io;
with ada.integer_text_io;		use ada.integer_text_io;
with ada.characters;			use ada.characters;
with ada.characters.latin_1;	use ada.characters.latin_1;
with ada.characters.handling; 	use ada.characters.handling;

with ada.strings; 				use ada.strings;
with ada.strings.bounded; 		use ada.strings.bounded;
with ada.strings.fixed; 		use ada.strings.fixed;
with ada.exceptions; 			use ada.exceptions;
 
with ada.command_line;			use ada.command_line;
with ada.directories;			use ada.directories;

with m1_base;					use m1_base;
with m1_database; 				use m1_database;
with m1_numbers; 				use m1_numbers;
with m1_files_and_directories;	use m1_files_and_directories;
with m1_test_gen_and_exec;		use m1_test_gen_and_exec;
with m1_string_processing;		use m1_string_processing;


procedure mktoggle is

	version			: string (1..3) := "001";
    prog_position	: natural := 0;

	use type_name_database;
	use type_device_name;
	use type_name_test;
	use type_pin_name;
	use type_port_name;
	use type_net_name;
    use type_list_of_bics;	
	use type_list_of_nets;
	use type_list_of_pins;
    use type_list_of_atg_expect_cells;
    use type_list_of_input_cells_class_NA;
    use type_list_of_static_expect_cells;

    target_net		: type_net_name.bounded_string;

	end_sdr			: type_end_sdr := PDR;
	end_sir			: type_end_sir := RTI;
    
	cycle_count_max	: constant positive := 20; -- CS: increase if neccessary. Greater values not reasonable.
	subtype type_cycle_count is positive range 1..cycle_count_max;
	cycle_count		: type_cycle_count;
	low_time		: type_delay_value;
	high_time		: type_delay_value;
	frequency		: float;
	




	procedure write_info_section is
	-- creates the sequence file,
	-- directs subsequent puts into the sequence file
	-- writes the info section into the sequence file

		colon_position : positive := 19;

	begin -- write_info_section
-- 		-- create sequence file
-- 		create( file_sequence, 
-- 			name => (compose (to_string(name_test), to_string(name_test), file_extension_sequence)));
-- 		set_output(file_sequence); -- set data sink

		put_line(file_sequence, section_mark.section & row_separator_0 & test_section.info);
		put_line(file_sequence, " created by " & name_module_mktoggle & " version "& version);
		put_line(file_sequence, row_separator_0 & section_info_item.date & (colon_position-(2+section_info_item.date'last)) * row_separator_0 & ": " & date_now);
		put_line(file_sequence, row_separator_0 & section_info_item.database & (colon_position-(2+section_info_item.database'last)) * row_separator_0 & ": " & to_string(name_file_database));
		put_line(file_sequence, row_separator_0 & section_info_item.name_test & (colon_position-(2+section_info_item.name_test'last)) * row_separator_0 & ": " & to_string(name_test));
		put_line(file_sequence, row_separator_0 & section_info_item.test_profile & (colon_position-(2+section_info_item.test_profile'last)) * row_separator_0 & ": " & type_test_profile'image(test_profile));
		put_line(file_sequence, row_separator_0 & section_info_item.end_sdr & (colon_position-(2+section_info_item.end_sdr'last)) * row_separator_0 & ": " & type_end_sdr'image(end_sdr));
		put_line(file_sequence, row_separator_0 & section_info_item.end_sir & (colon_position-(2+section_info_item.end_sir'last)) * row_separator_0 & ": " & type_end_sir'image(end_sir));

		put_line(file_sequence, row_separator_0 & section_info_item.target_net & (colon_position-(2+section_info_item.target_net'last)) * row_separator_0 & ": " & to_string(target_net));
		put_line(file_sequence, row_separator_0 & section_info_item.cycle_count & (colon_position-(2+section_info_item.cycle_count'last)) * row_separator_0 & ":" & type_cycle_count'image(cycle_count));
		put_line(file_sequence, row_separator_0 & section_info_item.low_time & (colon_position-(2+section_info_item.low_time'last)) * row_separator_0 & ":" & type_delay_value'image(low_time) & " sec");
		put_line(file_sequence, row_separator_0 & section_info_item.high_time & (colon_position-(2+section_info_item.high_time'last)) * row_separator_0 & ":" & type_delay_value'image(high_time) & " sec");
		put_line(file_sequence, row_separator_0 & section_info_item.frequency & (colon_position-(2+section_info_item.frequency'last)) * row_separator_0 & ":" & float'image(frequency) & " Hz");

		put_line(file_sequence, section_mark.endsection); 
		new_line(file_sequence);
	end write_info_section;




 	procedure atg_mktoggle is

		-- search in cell list atg_drive
		atg_drive			: type_ptr_cell_list_atg_drive := ptr_cell_list_atg_drive; -- Set pointer of atg_drive list at end of list.
		target_net_found	: boolean := false;
		drv_high			: type_bit_char_class_0 := '1';
		drv_low				: type_bit_char_class_0 := '0';
		driver_inverted		: boolean;

		procedure write_driver_cell(
			--cycle	: type_cycle_count;
			device 		: in type_device_name.bounded_string;
			cell 		: in type_cell_id;
			value 		: in type_bit_char_class_0;
			inverted	: in boolean := false;
			dely		: in type_delay_value
			) is
		begin
			if not inverted then
                put(file_sequence, row_separator_0 & comment & " drive "); 
			else
                put(file_sequence, row_separator_0 & comment & " drive (inverted) ");
			end if;
            put_character_class_0(file => file_sequence, char_in => value); 
            new_line(file_sequence);
            
			put(file_sequence, -- write sdr drive header (like "set IC301 drv boundary")
                row_separator_0 & sequence_instruction_set.set & row_separator_0 
                & to_string(device) & row_separator_0 & sxr_io_identifier.drive & row_separator_0 
                & sdr_target_register.boundary & type_cell_id'image(atg_drive.cell) 
                & sxr_assignment_operator.assign -- write cell id and assigment operator (like "45=")
				);

			-- write drive value
			if not inverted then
                put_character_class_0(file => file_sequence, char_in => value); 
			else
                put_character_class_0(file => file_sequence, char_in => negate_bit_character_class_0(value)); 
			end if;
			new_line(file_sequence);

            write_sdr; 
            new_line(file_sequence);
            put_line(file_sequence, row_separator_0 & sequence_instruction_set.dely & type_delay_value'image(dely)); 
            new_line(file_sequence);
		end write_driver_cell;

		procedure write_cycle (cycle : in type_cycle_count) is
		begin
			put_line(file_sequence, row_separator_0 & "----- cycle" & type_cycle_count'image(cycle) & " -----------------------" ); 
			new_line(file_sequence);
		end write_cycle;

	begin
		-- search in atg_drive list for target_net
		while atg_drive /= null
			loop
				if to_string(atg_drive.net) = to_string(target_net) then
					target_net_found := true;
					put_line(row_separator_0 & comment & type_cycle_count'image(cycle_count) & " cycles of LH follow ...");
					new_line;
					--put_line(column_separator_0);

					case atg_drive.class is
						when NR =>
 							-- CS: get init value from safebits

							for n in 1..cycle_count
								loop
									write_cycle(n);
									write_driver_cell(
										--cycle => n,
										device => to_string(atg_drive.device),
										cell => atg_drive.cell,
										value => drv_low,
										dely => low_time
										);

									write_driver_cell(
										--cycle => n,
										device => to_string(atg_drive.device),
										cell => atg_drive.cell,
										value => drv_high,
										dely => high_time
										);
								end loop;

						when PU | PD => null;
							-- CS: get init value from safebits

							-- Pull-nets frequently are controlled by a control cell. If the cell is to be inverted
							-- a flag is set. When assigning the drive value is is read.
							if atg_drive.controlled_by_control_cell then
								if atg_drive.inverted then
									driver_inverted := true; -- control cell must be inverted
								else 
									driver_inverted := false; -- control cell must not be inverted
								end if;
							else -- net driven by output cell
								driver_inverted := false; -- control cell must not be inverted
							end if;

							for n in 1..cycle_count
								loop
									write_cycle(n);
									write_driver_cell(
										device => to_string(atg_drive.device),
										cell => atg_drive.cell,
										value => drv_low,
										inverted => driver_inverted,
										dely => low_time
										);

									write_driver_cell(
										device => to_string(atg_drive.device),
										cell => atg_drive.cell,
										value => drv_high,
										inverted => driver_inverted,
										dely => high_time
										);
								end loop;

						when others => raise constraint_error; -- should never happen as nets in atg_drive are in class NR,PD or PU anyway
					end case;
				end if;

				atg_drive := atg_drive.next; -- advance pointer in atg_drive list
			end loop;
				
		-- target net found ?
		if target_net_found = false then
			set_output(standard_output);
			put("ERROR : Target net '" & to_string(target_net) & "' search failed !"); new_line(2);
			put("        Troubleshooting: Please verify that"); new_line (2);
			put("        1. target net is a primary net !"); new_line;
			put("        2. target net is in class NR, PU or PD !"); new_line;
			raise constraint_error;
		end if;
		
	end atg_mktoggle;



	procedure write_sequences is
	begin -- write_sequences
		new_line(2);

		all_in(sample);
		write_ir_capture;
		write_sir; new_line;

		load_safe_values;
		write_sdr; new_line;

		all_in(extest);
		write_sir; new_line;

		load_safe_values;
		write_sdr; new_line;

		load_static_drive_values;
		load_static_expect_values;
		write_sdr; new_line;

		atg_mktoggle;

		write_end_of_test;
	end write_sequences;






-------- MAIN PROGRAM ------------------------------------------------------------------------------------

begin
    test_profile	: type_test_profile := toggle;
    
	put_line("pin toggle generator version "& version);
	put_line("=====================================================");

	-- COMMAND LINE ARGUMENTS COLLECTING BEGIN
	prog_position	:= 10;
 	name_file_data_base:= to_bounded_string(Argument(1));
 	put_line ("data base      : " & to_string(name_file_data_base));
 
	prog_position	:= 20;
 	name_test:= to_bounded_string(Argument(2));
 	put_line ("test name      : " & to_string(name_test));

	prog_position	:= 30;
	target_net:= to_bounded_string(Argument(3));
	put_line ("target net     : " & to_string(target_net));
	
	prog_position	:= 40;
	cycle_count:= type_cycle_count'value(Argument(4));
	put_line ("cycle count    :" & type_cycle_count'image(cycle_count));
	
	prog_position	:= 50;
	low_time:= type_delay_value'value(argument(5));
	put_line ("low time       :" & type_delay_value'image(low_time) & " sec");
	
	prog_position	:= 60;
	high_time:= type_delay_value'value(Argument(6));
	put_line ("high time      :" & type_delay_value'image(high_time) & " sec");

	prog_position	:= 70;	
	frequency := 1.0/(high_time + low_time);
	put_line ("frequency      :" & float'image(frequency) & " Hz");
	-- COMMAND LINE ARGUMENTS COLLECTING DONE

	prog_position	:= 90;	
	read_data_base;

	prog_position	:= 100;
 	create_temp_directory;
	
	prog_position	:= 110;
	create_test_directory(
		test_name 			=> to_string(name_test),
		warnings_enabled 	=> false
		);

	prog_position	:= 120; 
	write_info_section;
	prog_position	:= 130;
	write_test_section_options;

	prog_position	:= 140;
	write_test_init;

	prog_position	:= 150;
	write_sequences;

	prog_position	:= 160;
	set_output(standard_output);

	prog_position	:= 170;
	close(file_sequence);

	prog_position	:= 180;
	write_diagnosis_netlist(
		data_base	=>	to_string(name_file_data_base),
		test_name	=>	to_string(name_test)
		);



	exception
		when event: others =>
			set_output(standard_output);
			set_exit_status(failure);
			case prog_position is
				when 10 =>
					put_line("ERROR: Data base file missing or insufficient access rights !");
					put_line("       Provide data base name as argument. Example: mktoggle my_uut.udb");
				when 20 =>
					put_line("ERROR: Test name missing !");
					put_line("       Provide test name as argument ! Example: mktoggle my_uut.udb my_toggle_test");
				when 40 =>
					put_line("ERROR: Invalid cycle count specified. Allowed range:" & type_cycle_count'image(type_cycle_count'first) &
						".." & type_cycle_count'image(type_cycle_count'last) & " !");
				when 50 =>
					put_line("ERROR: Invalid low time specified. Allowed range:" & type_delay_value'image(type_delay_value'first) &
						".." & type_delay_value'image(type_delay_value'last) & " !");
				when 60 =>
					put_line("ERROR: Invalid high time specified. Allowed range:" & type_delay_value'image(type_delay_value'first) &
						".." & type_delay_value'image(type_delay_value'last) & " !");


				when others =>
					put("unexpected exception: ");
					put_line(exception_name(event));
					put(exception_message(event)); new_line;
					put_line("program error at position " & natural'image(prog_position));
			end case;
			
end mktoggle;
