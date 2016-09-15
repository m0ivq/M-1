------------------------------------------------------------------------------
--                                                                          --
--                    SYSTEM M-1 MODULE MKTOGGLE                            --
--                                                                          --
--                                 M-1                                      --
--                                                                          --
--                               B o d y                                    --
--                                                                          --
--         Copyright (C) 2016 Mario Blunk, Blunk electronic                 --
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
--   Mario.Blunk@blunk-electronic.de
--   or visit <http://www.blunk-electronic.de> for more contact data
--
--   history of changes:
--


with ada.text_io;				use ada.text_io;
with ada.integer_text_io;		use ada.integer_text_io;
with ada.characters.handling; 	use ada.characters.handling;

with ada.strings; 				use ada.strings;
with ada.strings.bounded; 		use ada.strings.bounded;
with ada.strings.fixed; 		use ada.strings.fixed;
with ada.exceptions; 			use ada.exceptions;
with ada.numerics.elementary_functions; use ada.numerics.elementary_functions;
 
with ada.command_line;			use ada.command_line;
with ada.directories;			use ada.directories;

with m1;
with m1_files_and_directories; use m1_files_and_directories;
with m1_internal; use m1_internal;
with m1_numbers; use m1_numbers;


procedure mktoggle is

	version			: string (1..3) := "004";
	test_profile	: type_test_profile := toggle;
	end_sdr			: type_end_sdr := PDR;
	end_sir			: type_end_sir := RTI;


	target_net		: universal_string_type.bounded_string;

	cycle_count_max	: constant positive := 20; -- CS: increase if neccessary. Greater values not reasonable.
	subtype type_cycle_count is positive range 1..cycle_count_max;
	cycle_count		: type_cycle_count;
	low_time		: type_delay_value;
	high_time		: type_delay_value;
	frequency		: float; -- CS: range !
	
	prog_position	: natural := 0;



	procedure write_info_section is
	-- creates the sequence file,
	-- directs subsequent puts into the sequence file
	-- writes the info section into the sequence file

		colon_position : positive := 19;

	begin -- write_info_section
		-- create sequence file
		create( sequence_file, 
			name => (compose (universal_string_type.to_string(test_name), universal_string_type.to_string(test_name), file_extension_sequence)));
		set_output(sequence_file); -- set data sink

		put_line(section_mark.section & row_separator_0 & test_section.info);
		put_line(" created by pin toggle generator version "& version);
		put_line(row_separator_0 & section_info_item.date & (colon_position-(2+section_info_item.date'last)) * row_separator_0 & ": " & m1.date_now);
		put_line(row_separator_0 & section_info_item.data_base & (colon_position-(2+section_info_item.data_base'last)) * row_separator_0 & ": " & universal_string_type.to_string(data_base));
		put_line(row_separator_0 & section_info_item.test_name & (colon_position-(2+section_info_item.test_name'last)) * row_separator_0 & ": " & universal_string_type.to_string(test_name));
		put_line(row_separator_0 & section_info_item.test_profile & (colon_position-(2+section_info_item.test_profile'last)) * row_separator_0 & ": " & type_test_profile'image(test_profile));
		put_line(row_separator_0 & section_info_item.end_sdr & (colon_position-(2+section_info_item.end_sdr'last)) * row_separator_0 & ": " & type_end_sdr'image(end_sdr));
		put_line(row_separator_0 & section_info_item.end_sir & (colon_position-(2+section_info_item.end_sir'last)) * row_separator_0 & ": " & type_end_sir'image(end_sir));

		put_line(row_separator_0 & section_info_item.target_net & (colon_position-(2+section_info_item.target_net'last)) * row_separator_0 & ": " & universal_string_type.to_string(test_name));
		put_line(row_separator_0 & section_info_item.cycle_count & (colon_position-(2+section_info_item.cycle_count'last)) * row_separator_0 & ":" & type_cycle_count'image(cycle_count));
		put_line(row_separator_0 & section_info_item.low_time & (colon_position-(2+section_info_item.low_time'last)) * row_separator_0 & ":" & type_delay_value'image(low_time) & " sec");
		put_line(row_separator_0 & section_info_item.high_time & (colon_position-(2+section_info_item.high_time'last)) * row_separator_0 & ":" & type_delay_value'image(high_time) & " sec");
		put_line(row_separator_0 & section_info_item.frequency & (colon_position-(2+section_info_item.frequency'last)) * row_separator_0 & ":" & float'image(frequency) & " Hz");

		put_line(section_mark.endsection); 
		new_line;
	end write_info_section;




 	procedure atg_mktoggle is

		-- search in cell list atg_drive
		atg_drive			: type_ptr_cell_list_atg_drive := ptr_cell_list_atg_drive; -- Set pointer of atg_drive list at end of list.
		target_net_found	: boolean := false;

	begin
		while atg_drive /= null
			loop
-- 				-- if target cell is type output (NR Net)
-- 						if (Get_Field_Count(Line) = 10) and is_field(Line,"NR",2) then
-- 						
-- 							if Get_Field(Line,4) = target_net then -- on net name match
-- 											
-- 								net_found := true;
-- 								-- CS: get init value from safebits
-- 								--drv_value := 
-- 								new_line;
-- 								put (" -- toggle " & Line); new_line;	
-- 								put (" --" & Natural'Image(toggle_ct) & " cycles of LH follow ..."); new_line;			
-- 								put (" ----------------------------------------------------------------------------------------- "); new_line(2);
-- 																
-- 								for toggle_ct_tmp in 1..toggle_ct
-- 									loop
-- 										put (" -- cycle " & Natural'Image(toggle_ct_tmp)); new_line(2);
-- 										
-- 										put (" -- toggle L"); new_line;
-- 										put (" set " & Get_Field(Line,6) & " drv boundary " & Get_Field(Line,10) & "=0"); new_line;
-- 										vector_ct_tmp := write_sxr_file_open(vector_ct_tmp,0); -- 0 -> sdr , 1 -> sir
-- 										put (" delay "); put(low_time, fore=> 2, aft =>1, exp => 0); new_line(2);
-- 																				
-- 										put (" -- toggle H"); new_line;
-- 										put (" set " & Get_Field(Line,6) & " drv boundary " & Get_Field(Line,10) & "=1"); new_line;
-- 										vector_ct_tmp := write_sxr_file_open(vector_ct_tmp,0); -- 0 -> sdr , 1 -> sir
-- 										put (" delay "); put(high_time, fore=> 2, aft =>1, exp => 0); new_line(2);
-- 										put (" ----------------------------- "); new_line;
-- 									
-- 									end loop;
-- 							end if;
-- 						end if;				
-- 					
-- 					 	-- if target cell is type control (PU, PD Net)
-- 						if (Get_Field_Count(Line) = 12) and ( is_field(Line,"PU",2) or is_field(Line,"PD",2) ) then
-- 						
-- 							-- if net name matches and if no negation required
-- 							if Get_Field(Line,4) = target_net and is_field(Line,"no",12) then 
-- 								net_found := true;
-- 								
-- 								-- CS: get init value from safebits
-- 								--drv_value := 
-- 								new_line;
-- 								put (" -- toggle " & Line); new_line;	
-- 								put (" --" & Natural'Image(toggle_ct) & " cycles of LH follow ..."); new_line;			
-- 								put (" ----------------------------------------------------------------------------------------- "); new_line(2);
-- 																
-- 								for toggle_ct_tmp in 1..toggle_ct
-- 									loop
-- 										put (" -- cycle " & Natural'Image(toggle_ct_tmp)); new_line(2);
-- 										
-- 										put (" -- toggle L"); new_line;
-- 										put (" set " & Get_Field(Line,6) & " drv boundary " & Get_Field(Line,10) & "=0"); new_line;
-- 										vector_ct_tmp := write_sxr_file_open(vector_ct_tmp,0); -- 0 -> sdr , 1 -> sir
-- 										put (" delay "); put(low_time, fore=> 2, aft =>1, exp => 0); new_line(2);
-- 																				
-- 										put (" -- toggle H"); new_line;
-- 										put (" set " & Get_Field(Line,6) & " drv boundary " & Get_Field(Line,10) & "=1"); new_line;
-- 										vector_ct_tmp := write_sxr_file_open(vector_ct_tmp,0); -- 0 -> sdr , 1 -> sir
-- 										put (" delay "); put(high_time, fore=> 2, aft =>1, exp => 0); new_line(2);
-- 										put (" ----------------------------- "); new_line;
-- 									
-- 									end loop;
-- 							end if; -- if net name matches and if no negation required
-- 
-- 							-- if net name matches and if negation is required
-- 							if Get_Field(Line,4) = target_net and is_field(Line,"yes",12) then 
-- 								net_found := true;
-- 								
-- 								-- CS: get init value from safebits
-- 								--drv_value := 
-- 								new_line;
-- 								put (" -- toggle " & Line); new_line;	
-- 								put (" --" & Natural'Image(toggle_ct) & " cycles of LH follow ..."); new_line;			
-- 								put (" ----------------------------------------------------------------------------------------- "); new_line(2);
-- 																
-- 								for toggle_ct_tmp in 1..toggle_ct
-- 									loop
-- 										put (" -- cycle " & Natural'Image(toggle_ct_tmp)); new_line(2);
-- 										
-- 										put (" -- toggle L"); new_line;
-- 										put (" set " & Get_Field(Line,6) & " drv boundary " & Get_Field(Line,10) & "=1"); new_line;
-- 										vector_ct_tmp := write_sxr_file_open(vector_ct_tmp,0); -- 0 -> sdr , 1 -> sir
-- 										put (" delay "); put(low_time, fore=> 2, aft =>1, exp => 0); new_line(2);
-- 																				
-- 										put (" -- toggle H"); new_line;
-- 										put (" set " & Get_Field(Line,6) & " drv boundary " & Get_Field(Line,10) & "=0"); new_line;
-- 										vector_ct_tmp := write_sxr_file_open(vector_ct_tmp,0); -- 0 -> sdr , 1 -> sir
-- 										put (" delay "); put(high_time, fore=> 2, aft =>1, exp => 0); new_line(2);
-- 										put (" ----------------------------- "); new_line;
-- 									
-- 									end loop;
-- 							end if;	-- if net name matches and if negation is required
-- 
-- 
-- 						end if;				
-- 					
-- 					
-- 					end if;				
				atg_drive := atg_drive.next; -- advance pointer in atg_drive list
			end loop;
				
		-- target net found ?
		if target_net_found = false then
			set_output(standard_output);
			put("ERROR : Target net '" & universal_string_type.to_string(target_net) & "' search failed !"); new_line(2);
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

	put_line("pin toglle generator version "& version);
	put_line("=====================================================");

	-- COMMAND LINE ARGUMENTS COLLECTING BEGIN
	prog_position	:= 10;
 	data_base:= universal_string_type.to_bounded_string(Argument(1));
 	put_line ("data base      : " & universal_string_type.to_string(data_base));
 
	prog_position	:= 20;
 	test_name:= universal_string_type.to_bounded_string(Argument(2));
 	put_line ("test name      : " & universal_string_type.to_string(test_name));

	prog_position	:= 30;
	target_net:= universal_string_type.to_bounded_string(Argument(3));
	put_line ("target net     : " & universal_string_type.to_string(target_net));
	
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
	-- CS : frequency calculation ?
	
	prog_position	:= 80;
	if argument_count = 7 then
		debug_level := natural'value(argument(3));
		put_line("debug level    :" & natural'image(debug_level));
	end if;
	-- COMMAND LINE ARGUMENTS COLLECTING DONE

	prog_position	:= 90;	
	read_data_base;

	prog_position	:= 100;
 	create_temp_directory;
	
	prog_position	:= 110;
	create_test_directory(
		test_name 			=> universal_string_type.to_string(test_name),
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
	close(sequence_file);

	prog_position	:= 180;
	write_diagnosis_netlist(
		data_base	=>	universal_string_type.to_string(data_base),
		test_name	=>	universal_string_type.to_string(test_name)
		);



	exception
		when event: others =>
			set_output(standard_output);
			set_exit_status(failure);
			case prog_position is
				when 10 =>
					put_line("ERROR: Data base file missing or insufficient access rights !");
					put_line("       Provide data base name as argument. Example: mkmemcon my_uut.udb");
				when 20 =>
					put_line("ERROR: Test name missing !");
					put_line("       Provide test name as argument ! Example: mkmemcon my_uut.udb my_memory_test");
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
