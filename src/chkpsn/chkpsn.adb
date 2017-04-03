------------------------------------------------------------------------------
--                                                                          --
--                    SYSTEM M-1 MODULE CHKPSN                              --
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

with ada.text_io;				use ada.text_io;
with ada.characters.handling; 	use ada.characters.handling;
with ada.strings.bounded; 		use ada.strings.bounded;
with ada.strings.fixed; 		use ada.strings.fixed;
with ada.strings; 				use ada.strings;

with ada.containers;            use ada.containers;
with ada.containers.vectors;
with ada.containers.indefinite_vectors;

with ada.exceptions; 			use ada.exceptions;
with ada.command_line;			use ada.command_line;
with ada.directories;			use ada.directories;


with m1_base;					use m1_base;
with m1_database;				use m1_database;
with m1_files_and_directories; 	use m1_files_and_directories;
with m1_string_processing;		use m1_string_processing;

procedure chkpsn is

	version			: constant string (1..3) := "044";
	prog_position	: string (1..6) := "------";

	line_of_file	: type_universal_string.bounded_string;
	line_counter						: natural := 0;
	line_number_of_primary_net_header	: natural := 0;
	debug_level							: natural := 0;

-- 	database_backup_name				: type_name_database.bounded_string;
-- 	database_file_preliminary			: ada.text_io.file_type;
--	Previous_Output	: File_Type renames Current_Output;

	name_of_current_primary_net			: type_net_name.bounded_string;
	class_of_current_primary_net		: type_net_class := NA;
	primary_net_section_entered			: boolean := false;
	secondary_net_section_entered 		: boolean := false;	

	secondary_net_count					: natural := 0;
	list_of_secondary_net_names			: type_list_of_secondary_net_names.vector; -- CS: purge

	total_options_net_count				: natural := 0;

-- 	procedure read_data_base is
-- 	begin
-- 		read_uut_data_base(
-- 			name_of_data_base_file => universal_string_type.to_string(name_file_data_base),
-- 			debug_level => 0
-- 			); --.net_count_statistics.total > 0 then null; 
-- 	end read_data_base;

	type type_options_net (has_secondaries : boolean) is record
		name						: type_net_name.bounded_string;
		class						: type_net_class;
		line_number					: positive;
		case has_secondaries is
			when true =>
				list_of_secondary_net_names	: type_list_of_secondary_net_names.vector;
			when false =>
				null;
		end case;
	end record;
	package type_list_of_options_nets is new indefinite_vectors (index_type => positive, element_type => type_options_net);
	use type_list_of_options_nets;
	list_of_options_nets : type_list_of_options_nets.vector;

	procedure add_to_options_net_list(
		-- this procedure adds a primary net (incl. secondary nets) to the options net list
		-- multiple occurencs of nets in options file will be checked
		name_given							: in type_net_name.bounded_string;
		class_given							: in type_net_class;
		line_number_given					: in positive;
		list_of_secondary_net_names_given	: in type_list_of_secondary_net_names.vector
		) is
		
		secondary_net_count := length(list_of_secondary_net_names_given);
		-- CS: derive secondary net count from length of list_of_secondary_net_names_given

-- 		procedure verify_primary_net_appears_only_once (name : string) is
-- 			n	: type_ptr_options_net := ptr_options_net;
-- 		begin
-- 			prog_position := "OP3000";
-- 			while n /= null loop
-- 				if debug_level >= 50 then
-- 					put_line("searching primary net : " & universal_string_type.to_string(n.name) & " ...");
-- 				end if;
-- 
-- 				-- if primary net already specified as primary net:
-- 				if universal_string_type.to_string(n.name) = name then
-- 					prog_position := "OP3100";
-- 					put_line("ERROR: Net '" & name & "' already specified as primary net !");
-- 					raise constraint_error;
-- 				end if;
-- 
-- 				-- if primary net already specified as secondary net:
-- 				if n.has_secondaries then
-- 					for s in 1..n.secondary_net_count loop
-- 						if universal_string_type.to_string(n.list_of_secondary_net_names(s)) = name then
-- 							prog_position := "OP3200";
-- 							put_line("ERROR: Net '" & name & "' already specified as secondary net of primary net '" 
-- 								& universal_string_type.to_string(n.name) & "' !");
-- 							raise constraint_error;
-- 						end if;
-- 					end loop;
-- 				end if;
-- 				n := n.next;
-- 			end loop;
-- 		end verify_primary_net_appears_only_once;

-- 		procedure verify_secondary_net_appears_only_once (name : string) is
-- 		-- checks if secondary net appears only once in options file
-- 			n	: type_ptr_options_net := ptr_options_net;
-- 		begin
-- 			prog_position := "OP4000";
-- 			while n /= null loop
-- 				if debug_level >= 30 then
-- 					put_line("searching secondary net in primary net : " & universal_string_type.to_string(n.name) & " ...");
-- 				end if;
-- 
-- 
-- 				-- if secondary net already specified as primary net:
-- 				if universal_string_type.to_string(n.name) = name then
-- 					prog_position := "OP4100";
-- 					put_line("ERROR: Net '" & name & "' already specified as primary net !");
-- 					raise constraint_error;
-- 				end if;
-- 
-- 				-- if secondary net already specified as secondary net:
-- 				if n.has_secondaries then
-- 					for s in 1..n.secondary_net_count loop
-- 						if universal_string_type.to_string(n.list_of_secondary_net_names(s)) = name then
-- 							prog_position := "OP4200";
-- 							put_line("ERROR: Net '" & name & "' already specified as secondary net of primary net '" 
-- 								& universal_string_type.to_string(n.name) & "' !");
-- 							raise constraint_error;
-- 						end if;
-- 					end loop;
-- 				end if;
-- 				n := n.next;
-- 			end loop;
-- 		end verify_secondary_net_appears_only_once;

	begin -- add_to_options_net_list
-- CS:		verify_primary_net_appears_only_once(name_given); -- checks other primary nets and their secondary nets in options file

-- 		if debug_level >= 20 then
-- 			put_line("adding to options net list : " & name_given);
-- 		end if;

		case secondary_net_count is
			when 0 => 
				append(list_of_options_nets, ( has_secondaries => false, 
									   name => name_given,
									   class => class_given,
									   line_number => line_number_given ));

			when others =>
				-- if secondary nets present, the object to create does have a list of secondary nets which needs checking:
-- 				for s in 1..secondary_net_ct_given loop
-- 					if debug_level >= 30 then
-- 						put_line("checking secondary net : " & universal_string_type.to_string(list_of_secondary_net_names_given(s)) 
-- 							& "' for multiple occurences ...");
-- 					end if;

					-- CS: make sure the list of secondary nets does contain unique net names (means no multiple occurences of secondary nets within
					-- the same primary net 
-- 					for i in s+1..secondary_net_ct_given loop
-- 						if universal_string_type.to_string(list_of_secondary_net_names_given(s)) = universal_string_type.to_string(list_of_secondary_net_names_given(i)) then
-- 							prog_position := "OP2100";
-- 							put_line("ERROR: Net '" & universal_string_type.to_string(list_of_secondary_net_names_given(s)) & "' must be specified only once as secondary net of this primary net !");
-- 							raise constraint_error;
-- 						end if;
-- 					end loop;

					-- CS: check if current secondary net occurs in other primary and secondary nets
-- 					verify_secondary_net_appears_only_once(universal_string_type.to_string(list_of_secondary_net_names_given(s)));
-- 				end loop;

-- 				list := new type_options_net'(
-- 					next => list,
-- 					name					=> universal_string_type.to_bounded_string(name_given),
-- 					class					=> class_given,
-- 					line_number				=> line_number_given,
-- 					has_secondaries			=> true,
-- 					secondary_net_count		=> secondary_net_ct_given,
-- 					list_of_secondary_net_names	=> list_of_secondary_net_names_given
-- 					);
				
				append(list_of_options_nets, ( has_secondaries => true, 
									   name => name_given,
									   class => class_given,
									   line_number => line_number_given,
									   list_of_secondary_net_names => list_of_secondary_net_names_given));

		end case;

		-- update net counter of options file by: one primary net + number of attached secondaries
		total_options_net_count := total_options_net_count + 1 + secondary_net_count;

	end add_to_options_net_list;


	-- 		procedure update_cell_lists( d : type_ptr_net ) is
	procedure update_cell_lists( d : in type_net ) is
	-- updates cell lists by the net where d points to (in data base net list)
		drivers_without_disable_spec_ct 			: natural := 0;
		driver_with_non_shared_control_cell_found 	: boolean := false;
		driver_with_shared_control_cell_found		: boolean := false;

		p := type_pin;

-- 		procedure add_to_locked_control_cells_in_class_EH_EL_NA_nets(
-- 			-- prepares writing a cell list entry like:
-- 			-- class NA primary_net OSC_OUT device IC300 pin 6 control_cell 93 locked_to disable_value 0
-- 			-- class NA secondary_net OSC_OUT device IC300 pin 6 control_cell 93 locked_to disable_value 0
-- 			list				: in out type_ptr_cell_list_static_control_cells_class_EX_NA;
-- 			class_given			: type_net_class;
-- 			level_given			: type_net_level;
-- 			net_given			: universal_string_type.bounded_string;
-- 			device_given		: universal_string_type.bounded_string;
-- 			pin_given			: universal_string_type.bounded_string;
-- 			cell_given			: natural;
-- 			disable_value_given	: type_bit_char_class_0
-- 			) is
-- 		begin
-- 			list := new type_cell_list_static_control_cells_class_EX_NA'(
-- 				next 			=> list,
-- 				class			=> class_given,
-- 				level			=> level_given,
-- 				net				=> net_given,
-- 				device			=> device_given,
-- 				pin				=> pin_given,
-- 				cell			=> cell_given,
-- 				disable_value	=> disable_value_given
-- 				);
-- 		end add_to_locked_control_cells_in_class_EH_EL_NA_nets;

		procedure add_to_locked_control_cells_in_class_DH_DL_NR_nets(
			-- prepares writing a cell list entry like:
			-- class NR primary_net LED0 device IC303 pin 10 control_cell 16 locked_to enable_value 0
			-- class NR primary_net LED1 device IC303 pin 9 control_cell 16 locked_to enable_value 0
			-- class NR secondary_net LED7_R device IC301 pin 13 control_cell 75 locked_to disable_value 0
			list				: in out type_ptr_cell_list_static_control_cells_class_DX_NR;
			class_given			: type_net_class;
			level_given			: type_net_level;
			net_given			: universal_string_type.bounded_string;
			device_given		: universal_string_type.bounded_string;
			pin_given			: universal_string_type.bounded_string;
			cell_given			: natural;
			locked_to_enable_state_given	: boolean;
			enable_value_given				: type_bit_char_class_0 := '0';
			disable_value_given				: type_bit_char_class_0 := '0'
			) is
		begin
			case locked_to_enable_state_given is
				when true =>
					list := new type_cell_list_static_control_cells_class_DX_NR'(
						next 			=> list,
						class			=> class_given,
						level			=> level_given,
						net				=> net_given,
						device			=> device_given,
						pin				=> pin_given,
						cell			=> cell_given,
						locked_to_enable_state	=> true,
						enable_value			=> enable_value_given
						);
				when false =>
					list := new type_cell_list_static_control_cells_class_DX_NR'(
						next 			=> list,
						class			=> class_given,
						level			=> level_given,
						net				=> net_given,
						device			=> device_given,
						pin				=> pin_given,
						cell			=> cell_given,
						locked_to_enable_state	=> false,
						disable_value			=> disable_value_given
						);
			end case;
		end add_to_locked_control_cells_in_class_DH_DL_NR_nets;

		procedure add_to_locked_control_cells_in_class_PU_PD_nets(
			-- prepares writing a cell list entry like:
			-- class PD primary_net PD1 device IC301 pin 7 control_cell 87 locked_to disable_value 0
			-- class PD secondary_net PD1 device IC301 pin 7 control_cell 87 locked_to disable_value 0
			list				: in out type_ptr_cell_list_static_control_cells_class_PX;
			class_given			: type_net_class;
			level_given			: type_net_level;
			net_given			: universal_string_type.bounded_string;
			device_given		: universal_string_type.bounded_string;
			pin_given			: universal_string_type.bounded_string;
			cell_given			: natural;
			disable_value_given				: type_bit_char_class_0
			) is
		begin
			list := new type_cell_list_static_control_cells_class_PX'(
				next 			=> list,
				class			=> class_given,
				level			=> level_given,
				net				=> net_given,
				device			=> device_given,
				pin				=> pin_given,
				cell			=> cell_given,
				disable_value	=> disable_value_given
				);
		end add_to_locked_control_cells_in_class_PU_PD_nets;

		procedure add_to_locked_output_cells_in_class_PU_PD_nets(
			-- prepares writing a cell list entry like:
			-- class PU primary_net /SYS_RESET device IC300 pin 39 output_cell 37 locked_to drive_value 0
			list				: in out type_ptr_cell_list_static_output_cells_class_PX;
			class_given			: type_net_class;
			net_given			: universal_string_type.bounded_string;
			device_given		: universal_string_type.bounded_string;
			pin_given			: universal_string_type.bounded_string;
			cell_given			: natural;
			drive_value_given	: type_bit_char_class_0
			) is
		begin
			list := new type_cell_list_static_output_cells_class_PX'(
				next 			=> list,
				class			=> class_given,
				net				=> net_given,
				device			=> device_given,
				pin				=> pin_given,
				cell			=> cell_given,
				drive_value		=> drive_value_given
				);
		end add_to_locked_output_cells_in_class_PU_PD_nets;

		procedure add_to_locked_output_cells_in_class_DH_DL_nets(
			-- prepares writing a cell list entry like:
			-- class DL primary_net /CPU_MREQ device IC300 pin 28 output_cell 13 locked_to drive_value 0
			-- class DH primary_net /CPU_RD device IC300 pin 27 output_cell 10 locked_to drive_value 1
			list				: in out type_ptr_cell_list_static_output_cells_class_DX_NR;
			class_given			: type_net_class;
			--level_given			: type_net_level := primary; -- because this is always a primary net
			net_given			: universal_string_type.bounded_string;
			device_given		: universal_string_type.bounded_string;
			pin_given			: universal_string_type.bounded_string;
			cell_given			: natural;
			drive_value_given	: type_bit_char_class_0
			) is
		begin
			list := new type_cell_list_static_output_cells_class_DX_NR'(
				next 			=> list,
				class			=> class_given,
				--level			=> level_given,
				net				=> net_given,
				device			=> device_given,
				pin				=> pin_given,
				cell			=> cell_given,
				drive_value		=> drive_value_given
				);
		end add_to_locked_output_cells_in_class_DH_DL_nets;

-- 		procedure add_to_static_expect(
-- 			-- prepares writing a cell list entry like:
-- 			-- class DL primary_net /CPU_MREQ device IC300 pin 28 input_cell 14 expect_value 0
-- 			-- class DL secondary_net /CPU_MREQ device IC300 pin 28 input_cell 14 expect_value 0
-- 			list				: in out type_ptr_cell_list_static_expect;
-- 			class_given			: type_net_class;
-- 			level_given			: type_net_level;
-- 			net_given			: universal_string_type.bounded_string;
-- 			device_given		: universal_string_type.bounded_string;
-- 			pin_given			: universal_string_type.bounded_string;
-- 			cell_given			: natural;
-- 			expect_value_given	: type_bit_char_class_0;
-- 			primary_net_is_given: universal_string_type.bounded_string
-- 			) is
-- 		begin
-- 			case level is
-- 				when primary =>
-- 					list := new type_cell_list_static_expect'(
-- 						next 			=> list,
-- 						class			=> class_given,
-- 						level			=> primary,
-- 						net				=> net_given,
-- 						device			=> device_given,
-- 						pin				=> pin_given,
-- 						cell			=> cell_given,
-- 						expect_value	=> expect_value_given
-- 						);
-- 
-- 				when secondary =>
-- 					list := new type_cell_list_static_expect'(
-- 						next 			=> list,
-- 						class			=> class_given,
-- 						level			=> secondary,
-- 						net				=> net_given,
-- 						device			=> device_given,
-- 						pin				=> pin_given,
-- 						cell			=> cell_given,
-- 						expect_value	=> expect_value_given,
-- 						primary_net_is	=> primary_net_is_given -- reference to primary net required here
-- 						);
-- 			end case; -- level
-- 		end add_to_static_expect;

-- 		procedure add_to_atg_expect(
-- 			-- prepares writing a cell list entry like:
-- 			-- class PU secondary_net CT_D3 device IC303 pin 19 input_cell 11 primary_net_is D3
-- 			-- class PU primary_net /CPU_WR device IC300 pin 26 input_cell 8
-- 			list				: in out type_ptr_cell_list_atg_expect;
-- 			class_given			: type_net_class;
-- 			level_given			: type_net_level;
-- 			net_given			: universal_string_type.bounded_string;
-- 			device_given		: universal_string_type.bounded_string;
-- 			pin_given			: universal_string_type.bounded_string;
-- 			cell_given			: natural;
-- 			primary_net_is_given: universal_string_type.bounded_string
-- 			) is
-- 		begin
-- 			case level_given is
-- 				when primary =>
-- 					list := new type_cell_list_atg_expect'(
-- 						next 			=> list,
-- 						class			=> class_given,
-- 						level			=> primary,
-- 						net				=> net_given,
-- 						device			=> device_given,
-- 						pin				=> pin_given,
-- 						cell			=> cell_given
-- 						);
-- 				when secondary =>
-- 					list := new type_cell_list_atg_expect'(
-- 						next 			=> list,
-- 						class			=> class_given,
-- 						level			=> secondary,
-- 						net				=> net_given,
-- 						device			=> device_given,
-- 						pin				=> pin_given,
-- 						cell			=> cell_given,
-- 						primary_net_is	=> primary_net_is_given -- reference to primary net required here
-- 						);
-- 			end case;
-- 		end add_to_atg_expect;

		procedure add_to_atg_drive(
			-- prepares writing a cell list entry like:
			-- class NR primary_net LED7 device IC303 pin 2 output_cell 7
			-- class PU primary_net /CPU_WR device IC300 pin 26 control_cell 6 inverted yes
			-- class PD primary_net /DRV_EN device IC301 pin 27 control_cell 9 inverted no
			list				: in out type_ptr_cell_list_atg_drive;
			class_given			: type_net_class;
			net_given			: universal_string_type.bounded_string;
			device_given		: universal_string_type.bounded_string;
			pin_given			: universal_string_type.bounded_string;
			cell_given			: natural;
			controlled_by_control_cell_given	: boolean; -- if controlled by output cell -> false
			-- examples for controlled_by_control_cell_given = true:
			-- class PU primary_net /CPU_WR device IC300 pin 26 control_cell 6 inverted yes
			-- class PD primary_net /DRV_EN device IC301 pin 27 control_cell 9 inverted no
			control_cell_inverted_given			: boolean := false -- default in case it is not required

			-- example for controlled_by_control_cell_given = false:
			-- class NR primary_net LED7 device IC303 pin 2 output_cell 7
			) is
		begin
			case controlled_by_control_cell_given is
				when true =>
					list := new type_cell_list_atg_drive'(
						next 			=> list,
						class			=> class_given,
						--level			=> secondary,
						net				=> net_given,
						device			=> device_given,
						pin				=> pin_given,
						cell			=> cell_given,
						controlled_by_control_cell	=> true,
						inverted					=> control_cell_inverted_given
						);
				when false =>
					list := new type_cell_list_atg_drive'(
						next 			=> list,
						class			=> class_given,
						--level			=> secondary,
						net				=> net_given,
						device			=> device_given,
						pin				=> pin_given,
						cell			=> cell_given,
						controlled_by_control_cell	=> false
						);
			end case;
		end add_to_atg_drive;

		procedure add_to_input_cells_in_class_NA_nets(
			-- prepares writing a cell list entry like:
			-- class NA primary_net OSC_OUT device IC301 pin 6 input_cell 95
			-- class NA secondary_net LED0_R device IC301 pin 2 input_cell 107 primary_net_is LED0
			list				: in out type_ptr_cell_list_input_cells_class_NA;
			level_given			: type_net_level;
			net_given			: universal_string_type.bounded_string;
			device_given		: universal_string_type.bounded_string;
			pin_given			: universal_string_type.bounded_string;
			cell_given			: natural;
			primary_net_is_given: universal_string_type.bounded_string
			) is
		begin
			case level_given is
				when primary =>
					list := new type_cell_list_input_cells_class_NA'(
						next 			=> list,
						level			=> primary,
						net				=> net_given,
						device			=> device_given,
						pin				=> pin_given,
						cell			=> cell_given
						);
				when secondary =>
					list := new type_cell_list_input_cells_class_NA'(
						next 			=> list,
						level			=> secondary,
						net				=> net_given,
						device			=> device_given,
						pin				=> pin_given,
						cell			=> cell_given,
						primary_net_is	=> primary_net_is_given -- reference to primary net required here
						);
			end case;
		end add_to_input_cells_in_class_NA_nets;

		function control_cell_in_enable_state_by_any_cell_list(
		-- searches cell lists for given control cell and returns false if cell is not in enable state
		-- aborts if cell in enable state or targeted by atg
			class		: type_net_class;
			net			: universal_string_type.bounded_string;
			device		: universal_string_type.bounded_string;
			cell_id		: natural) 
			return boolean is
			a : type_ptr_cell_list_static_control_cells_class_DX_NR	:= ptr_cell_list_static_control_cells_class_DX_NR;
			b : type_ptr_cell_list_atg_drive						:= ptr_cell_list_atg_drive;

			procedure print_error_on_shared_control_cell_conflict is
			begin
				put_line(standard_output,"ERROR: Shared control cell conflict in class " & type_net_class'image(class) 
					& " net '" & universal_string_type.to_string(net) & "' !");
			end print_error_on_shared_control_cell_conflict;

		begin
			while a /= null loop -- loop through cell list indicated by pointer a (locked_control_cells_in_class_DH_DL_NR_nets)
				if universal_string_type.to_string(a.device) = universal_string_type.to_string(device) then -- on device name match
					if a.cell = cell_id then -- on cell id match
						if a.locked_to_enable_state = true then -- if locked to enable state
							print_error_on_shared_control_cell_conflict;
							put_line(standard_output,"       Device '" & universal_string_type.to_string(a.device) 
								& "' control cell" & natural'image(a.cell)
								& " already locked to enable state " & type_bit_char_class_0'image(a.enable_value));
							put_line(standard_output,"       by class " & type_net_class'image(a.class) & row_separator_0 
								& to_lower(type_net_level'image(a.level)) 
								& " net '" & universal_string_type.to_string(a.net) & "' !");
							raise constraint_error;
						end if; -- if locked to enable state
					end if; -- in cell id match
				end if; -- on device name match
				a := a.next;
			end loop;

			while b /= null loop -- loop through cell list indicated by pointer c (atg_drive)
				if universal_string_type.to_string(b.device) = universal_string_type.to_string(device) then -- on device name match
					if b.cell = cell_id then -- on cell id match
						if b.controlled_by_control_cell then -- if control cell is targeted by atg
							print_error_on_shared_control_cell_conflict;
							put_line(standard_output,"       Device '" & universal_string_type.to_string(b.device) 
								& "' control cell" & natural'image(b.cell)
								& " already reserved for ATG");
							put_line(standard_output,"       by class " & type_net_class'image(b.class) & row_separator_0 
								& " primary net '" & universal_string_type.to_string(b.net) & "' !");
							raise constraint_error;
						end if; -- if targeted by atg
					end if;
				end if;
				b := b.next;
			end loop;

			-- given control cell is not in enable state
			return false;
		end control_cell_in_enable_state_by_any_cell_list;


		function control_cell_in_disable_state_by_any_cell_list(
		-- searches cell lists for given control cell and returns false if cell is not in disable state
		-- aborts if cell in disable state or targeted by atg
			class		: type_net_class;
			net			: universal_string_type.bounded_string;
			device		: universal_string_type.bounded_string;
			cell_id		: natural) 
			return boolean is
			--sj	: type_shared_control_cell_journal_ptr := shared_control_cell_journal_ptr;
			a : type_ptr_cell_list_static_control_cells_class_EX_NA	:= ptr_cell_list_static_control_cells_class_EX_NA;
			b : type_ptr_cell_list_static_control_cells_class_DX_NR	:= ptr_cell_list_static_control_cells_class_DX_NR;
			c : type_ptr_cell_list_static_control_cells_class_PX 	:= ptr_cell_list_static_control_cells_class_PX;
			d : type_ptr_cell_list_atg_drive						:= ptr_cell_list_atg_drive;

			procedure print_error_on_shared_control_cell_conflict is
			begin
				put_line(standard_output,"ERROR: Shared control cell conflict in class " & type_net_class'image(class) 
					& " net '" & universal_string_type.to_string(net) & "' !");
			end print_error_on_shared_control_cell_conflict;

		begin -- control_cell_in_disable_state_by_any_cell_list
			while a /= null loop -- loop through cell list indicated by pointer a (locked_control_cells_in_class_EH_EL_NA_nets)
				if universal_string_type.to_string(a.device) = universal_string_type.to_string(device) then -- on device name match
					if a.cell = cell_id then -- on cell id match
						print_error_on_shared_control_cell_conflict;
						put_line(standard_output,"       Device '" & universal_string_type.to_string(a.device) 
							& "' control cell" & natural'image(a.cell)
							& " already locked to disable state " & type_bit_char_class_0'image(a.disable_value));
						put_line(standard_output,"       by class " & type_net_class'image(a.class) & row_separator_0 
							& to_lower(type_net_level'image(a.level)) 
							& " net '" & universal_string_type.to_string(a.net) & "' !");
						raise constraint_error;
					end if;
				end if;
				a := a.next;
			end loop;

			while b /= null loop -- loop through cell list indicated by pointer b (locked_control_cells_in_class_DH_DL_NR_nets)
				if universal_string_type.to_string(b.device) = universal_string_type.to_string(device) then -- on device name match
					if b.cell = cell_id then -- on cell id match
						if b.locked_to_enable_state = false then -- if locked to disable state
							print_error_on_shared_control_cell_conflict;
							put_line(standard_output,"       Device '" & universal_string_type.to_string(b.device) 
								& "' control cell" & natural'image(b.cell)
								& " already locked to disable state " & type_bit_char_class_0'image(b.disable_value));
							put_line(standard_output,"       by class " & type_net_class'image(b.class) & row_separator_0 
								& to_lower(type_net_level'image(b.level)) 
								& " net '" & universal_string_type.to_string(b.net) & "' !");
							raise constraint_error;
						end if; -- if locked to disable state
					end if;
				end if;
				b := b.next;
			end loop;

			-- CS: not tested yet:
			while c /= null loop -- loop through cell list indicated by pointer c (locked_control_cells_in_class_PU_PD_nets)
				if universal_string_type.to_string(c.device) = universal_string_type.to_string(device) then -- on device name match
					if c.cell = cell_id then -- on cell id match
						--if c.locked_to_enable_state = false then -- if locked to disable state
							print_error_on_shared_control_cell_conflict;
							put_line(standard_output,"       Device '" & universal_string_type.to_string(c.device) 
								& "' control cell" & natural'image(c.cell)
								& " already locked to disable state " & type_bit_char_class_0'image(c.disable_value));
							put_line(standard_output,"       by class " & type_net_class'image(c.class) & row_separator_0 
								& to_lower(type_net_level'image(c.level)) 
								& " net '" & universal_string_type.to_string(c.net) & "' !");
							raise constraint_error;
						--end if; -- if locked to disable state
					end if;
				end if;
				c := c.next;
			end loop;

			-- CS: not tested yet:
			while d /= null loop -- loop through cell list indicated by pointer c (atg_drive)
				if universal_string_type.to_string(d.device) = universal_string_type.to_string(device) then -- on device name match
					if d.cell = cell_id then -- on cell id match
						if d.controlled_by_control_cell then -- if control cell is targeted by atg
							print_error_on_shared_control_cell_conflict;
							put_line(standard_output,"       Device '" & universal_string_type.to_string(d.device) 
								& "' control cell" & natural'image(d.cell)
								& " already reserved for ATG");
							put_line(standard_output,"       by class " & type_net_class'image(d.class) & row_separator_0 
								& " primary net '" & universal_string_type.to_string(d.net) & "' !");
							raise constraint_error;
						end if; -- if targeted by atg
					end if;
				end if;
				d := d.next;
			end loop;

			-- given control cell is not in disable state
			return false;
		end control_cell_in_disable_state_by_any_cell_list;

		procedure disable_remaining_drivers ( d : type_ptr_net) is
		begin
			if debug_level >= 30 then
				put_line(standard_output,"disabling remaining drivers in net " & row_separator_0 & universal_string_type.to_string(d.name));
			end if;

			-- FIND CONTROL CELLS TO BE DISABLED:
			prog_position := "DD1000";
			for p in 1..d.part_ct loop -- loop through pin list of given net
				if d.pin(p).is_bscan_capable then -- care for scan capable pins only
					-- pin must have a control cell and an output cell
					if d.pin(p).cell_info.control_cell_id /= -1 and d.pin(p).cell_info.output_cell_id /= -1 then 
						prog_position := "DD1100";
						if not d.pin(p).cell_info.selected_as_driver then -- care for drivers not marked as active

							if debug_level >= 35 then
								put_line(standard_output," driver pin : " 
--											& row_separator_0 & universal_string_type.to_string(d.name)
									& row_separator_0 & universal_string_type.to_string(d.pin(p).device_name)
									& row_separator_0 & universal_string_type.to_string(d.pin(p).device_pin_name)
									);
							end if;

							-- if non-shared control cell, just turn it off:
							--  write disable value in cell list
							--  write drive value 0 of useless output cell in cell list
							if not d.pin(p).cell_info.control_cell_shared then
								prog_position := "DD1300";
								case class is
									when DH | DL | NR =>
										-- add control cell to list
										prog_position := "DD1400";
										add_to_locked_control_cells_in_class_DH_DL_NR_nets(
											-- prepares writing a cell list entry like:
											-- class NR secondary_net LED7_R device IC301 pin 13 control_cell 75 locked_to disable_value 0
											list				=> ptr_cell_list_static_control_cells_class_DX_NR,
											class_given			=> class,
											level_given			=> level,
											net_given			=> universal_string_type.to_bounded_string(name),
											device_given		=> d.pin(p).device_name,
											pin_given			=> d.pin(p).device_pin_name,
											cell_given			=> d.pin(p).cell_info.control_cell_id,
											locked_to_enable_state_given	=> false, -- the pin is to be disabled
											disable_value_given				=> d.pin(p).cell_info.disable_value
											);

										-- add (unused) output cell to list
										prog_position := "DD1410";
										add_to_locked_output_cells_in_class_DH_DL_nets(
											list				=> ptr_cell_list_static_output_cells_class_DX_NR,
											class_given			=> class,
											net_given			=> universal_string_type.to_bounded_string(name),
											device_given		=> d.pin(p).device_name,
											pin_given			=> d.pin(p).device_pin_name,
											cell_given			=> d.pin(p).cell_info.output_cell_id,
											drive_value_given	=> '0' --drive_value_derived_from_class(class) 
												-- the drive value is meaningless since the pin is disabled
											);


									when PU | PD =>
										-- add control cell to list
										prog_position := "DD1500";
										add_to_locked_control_cells_in_class_PU_PD_nets(
											-- prepares writing a cell list entry like:
											-- class PD primary_net PD1 device IC301 pin 7 control_cell 87 locked_to disable_value 0
											-- class PD secondary_net PD1 device IC301 pin 7 control_cell 87 locked_to disable_value 0
											list				=> ptr_cell_list_static_control_cells_class_PX,
											class_given			=> class,
											level_given			=> level,
											net_given			=> universal_string_type.to_bounded_string(name),
											device_given		=> d.pin(p).device_name,
											pin_given			=> d.pin(p).device_pin_name,
											cell_given			=> d.pin(p).cell_info.control_cell_id,
											disable_value_given				=> d.pin(p).cell_info.disable_value
											);
									when others => null;
								end case;
							else
							-- if shared control cell
								prog_position := "DD2000";

								-- check if control cell can be set to disable state
								if not control_cell_in_enable_state_by_any_cell_list( 
									net		=> d.name,
									class	=> class,
									device	=> d.pin(p).device_name,
									cell_id	=> d.pin(p).cell_info.control_cell_id) then

									case class is
										when DH | DL | NR =>
											-- add control cell to list
											prog_position := "DD2100";
											add_to_locked_control_cells_in_class_DH_DL_NR_nets(
												-- prepares writing a cell list entry like:
												-- class NR secondary_net LED7_R device IC301 pin 13 control_cell 75 locked_to disable_value 0
												list				=> ptr_cell_list_static_control_cells_class_DX_NR,
												class_given			=> class,
												level_given			=> level,
												net_given			=> universal_string_type.to_bounded_string(name),
												device_given		=> d.pin(p).device_name,
												pin_given			=> d.pin(p).device_pin_name,
												cell_given			=> d.pin(p).cell_info.control_cell_id,
												locked_to_enable_state_given	=> false, -- the pin is to be disabled
												disable_value_given				=> d.pin(p).cell_info.disable_value
												);

											-- add (unused) output cell to list
											prog_position := "DD2110";
											add_to_locked_output_cells_in_class_DH_DL_nets(
												list				=> ptr_cell_list_static_output_cells_class_DX_NR,
												class_given			=> class,
												net_given			=> universal_string_type.to_bounded_string(name),
												device_given		=> d.pin(p).device_name,
												pin_given			=> d.pin(p).device_pin_name,
												cell_given			=> d.pin(p).cell_info.output_cell_id,
												drive_value_given	=> '0' --drive_value_derived_from_class(class) 
													-- the drive value is meaningless since the pin is disabled
												);


										when PU | PD =>
											-- add control cell to list
											prog_position := "DD2200";
											add_to_locked_control_cells_in_class_PU_PD_nets(
												-- prepares writing a cell list entry like:
												-- class PD primary_net PD1 device IC301 pin 7 control_cell 87 locked_to disable_value 0
												-- class PD secondary_net PD1 device IC301 pin 7 control_cell 87 locked_to disable_value 0
												list				=> ptr_cell_list_static_control_cells_class_PX,
												class_given			=> class,
												level_given			=> level,
												net_given			=> universal_string_type.to_bounded_string(name),
												device_given		=> d.pin(p).device_name,
												pin_given			=> d.pin(p).device_pin_name,
												cell_given			=> d.pin(p).cell_info.control_cell_id,
												disable_value_given	=> d.pin(p).cell_info.disable_value
												);
										when others => null;
									end case;
								end if; -- check if control cell can be set to disable state

							end if; -- if non-shared control cell, just turn it off
						end if;  -- care for drivers not marked as active
					end if; -- pin must have a control cell and an output cell
				end if;
			end loop;
		end disable_remaining_drivers;


	begin -- update_cell_lists
		-- d is a net pointer and points to the net being processed

-- 			if debug_level >= 30 then
-- 				put_line(standard_output," updating cell lists with net " & universal_string_type.to_string(d.name));
-- 			end if;

		-- FIND INPUT CELLS AND CONTROL CELLS TO BE DISABLED:
		-- 		for p in 1..d.part_ct loop -- loop through pin list of given net
		for i in 1..length(d.pins) loop
			p := element(d.pins, positive(i));

			-- CS: add a variable that holds the pin count of the net

			if p.is_bscan_capable then -- care for scan capable pins only

				-- THIS IS ABOUT INPUT CELLS:
				-- add all input cells of static and dynamic (atg) nets to cell list "static_expect" and "atg_expect"
				-- since all input cells are listening, the net level (primary/secondary) does not matter
				-- here and will not be evaluated
				if p.cell_info.input_cell_id /= -1 then -- if pin does have an input cell
					case class is
						when EH | EL | DH | DL =>
							case d.level is
								when primary =>
									append(list_of_static_expect_cells,(
										level			=> primary,
										class			=> d.class,
										net				=> to_bounded_string(d.name),
										device			=> p.device_name,
										pin				=> p.pin,
										id				=> p.cell_info.input_cell_id,
										expect_value	=> expect_value_derived_from_class(class));
							   when secondary =>
									append(list_of_static_expect_cells,(
										level			=> secondary,
										primary_net_is	=> d.primary_net_is,
										class			=> d.class,
										net				=> to_bounded_string(d.name),
										device			=> p.device_name,
										pin				=> p.pin,
										id				=> p.cell_info.input_cell_id,
										expect_value	=> expect_value_derived_from_class(class));
							end case;
							
						when NR | PU | PD =>

-- 							add_to_atg_expect(
-- 								list			=> ptr_cell_list_atg_expect,
-- 								class_given		=> class,
-- 								level_given		=> level, 
-- 								-- if secondary net, the argument "primary_net_is" will be evaluated, otherwise ignored
-- 								primary_net_is_given	=> primary_net_is,
-- 								net_given		=> universal_string_type.to_bounded_string(name),
-- 								device_given	=> d.pin(p).device_name,
-- 								pin_given		=> d.pin(p).device_pin_name,
-- 								cell_given		=> d.pin(p).cell_info.input_cell_id
-- 								);
						
							case d.level is
								when primary =>
									append(list_of_atg_expect_cells,(
										level			=> primary,
										class			=> d.class,
										net				=> to_bounded_string(d.name),
										device			=> p.device_name,
										pin				=> p.pin,
										id				=> p.cell_info.input_cell_id);
							   when secondary =>
									append(list_of_atg_expect_cells,(
										level			=> secondary,
										primary_net_is	=> d.primary_net_is,
										class			=> d.class,
										net				=> to_bounded_string(d.name),
										device			=> p.device_name,
										pin				=> p.pin,
										id				=> p.cell_info.input_cell_id);
							end case;

						when NA =>
-- 							add_to_input_cells_in_class_NA_nets(
-- 								list			=> ptr_cell_list_input_cells_class_NA,
-- 								level_given		=> level, 
-- 								-- if secondary net, the argument "primary_net_is" will be evaluated, otherwise ignored
-- 								primary_net_is_given	=> primary_net_is,
-- 								net_given		=> universal_string_type.to_bounded_string(name),
-- 								device_given	=> d.pin(p).device_name,
-- 								pin_given		=> d.pin(p).device_pin_name,
-- 								cell_given		=> d.pin(p).cell_info.input_cell_id
-- 								);
							case d.level is
								when primary =>
									append(list_of_input_cells_class_NA,(
										level			=> primary,
										class			=> d.class,
										net				=> to_bounded_string(d.name),
										device			=> p.device_name,
										pin				=> p.pin,
										id				=> p.cell_info.input_cell_id);
							   when secondary =>
									append(list_of_input_cells_class_NA,(
										level			=> secondary,
										primary_net_is	=> d.primary_net_is,
										class			=> d.class,
										net				=> to_bounded_string(d.name),
										device			=> p.device_name,
										pin				=> p.pin,
										id				=> p.cell_info.input_cell_id);
							end case;

					end case; -- class
				end if;

				-- THIS IS ABOUT CONTROL CELLS IN PRIMARY AND SECONDARY NETS OF CLASS EH, EL, NA:
				-- in nets of class EH, EL or NA, all control cells must be in disable state, regardless of net level
				if p.cell_info.control_cell_id /= -1 then -- if pin has disable spec. (means: a control cell)

					case class is
						when EL | EH | NA =>

							if p.cell_info.control_cell_shared then
								-- if driver has a shared control cell
								-- the driver pin can be disabled if its control cell is not already enabled 
								-- or targeted by atg

								-- check if control cell can be set to disable state
								if not control_cell_in_enable_state_by_any_cell_list( 
									net		=> d.name,
									class	=> d.class,
									device	=> p.device_name,
									cell_id	=> p.cell_info.control_cell_id) then

										-- all control cells of those nets must be in disable state (don't care about net level)
-- 										add_to_locked_control_cells_in_class_EH_EL_NA_nets(
-- 											list				=> ptr_cell_list_static_control_cells_class_EX_NA,
-- 											class_given			=> class,
-- 											level_given			=> level,
-- 											net_given			=> universal_string_type.to_bounded_string(name),
-- 											device_given		=> d.pin(p).device_name,
-- 											pin_given			=> d.pin(p).device_pin_name,
-- 											cell_given			=> d.pin(p).cell_info.control_cell_id,
-- 											disable_value_given	=> d.pin(p).cell_info.disable_value
-- 											);

									append(list_of_static_control_cells_class_EX_NA, (
										level			=> d.level,																					 
										class			=> d.class,
										net				=> to_bounded_string(d.name),
										device			=> p.device_name,
										pin				=> p.pin,
										id				=> p.cell_info.control_cell_id,
										disable_value	=> p.cell_info.disable_value);
								end if;

							else -- driver has a non-shared control cell
								-- so there is no need to check cell lists 
								-- all control cells of those nets must be in disable state

-- 								add_to_locked_control_cells_in_class_EH_EL_NA_nets(
-- 									list				=> ptr_cell_list_static_control_cells_class_EX_NA,
-- 									class_given			=> class,
-- 									level_given			=> level,
-- 									net_given			=> universal_string_type.to_bounded_string(name),
-- 									device_given		=> d.pin(p).device_name,
-- 									pin_given			=> d.pin(p).device_pin_name,
-- 									cell_given			=> d.pin(p).cell_info.control_cell_id,
-- 									disable_value_given	=> d.pin(p).cell_info.disable_value
-- 									);

								append(list_of_static_control_cells_class_EX_NA, (
									level			=> d.level,																					 
									class			=> d.class,
									net				=> to_bounded_string(d.name),
									device			=> p.device_name,
									pin				=> p.pin,
									id				=> p.cell_info.control_cell_id,
									disable_value	=> p.cell_info.disable_value);

							end if; -- if driver has a shared control cell

						when others => 
							null;
-- 							prog_position := "UC2230";
					end case;
				end if;


				-- THIS IS ABOUT CONTROL CELLS IN SECONDARY NETS IN CLASS DH , DL , NR , PU AND PD:
				case d.level is
					when secondary =>
						-- all control cells in secondary nets must be in disable state
						if p.cell_info.control_cell_id /= -1 then -- if pin has a control cell
							case class is
								when EL | EH | NA =>
-- 									prog_position := "UC2310"; -- no need to disable control cells again, as this has been done earlier (see above)
									null;
									--add_to_locked_control_cells_in_class_EH_EL_NA_nets(
									--	list				=> cell_list_locked_control_cells_in_class_EH_EL_NA_nets_ptr,
									--	class_given			=> class,
									--	level_given			=> level,
									--	net_given			=> universal_string_type.to_bounded_string(name),
									--	device_given		=> d.pin(p).device_name,
									--	pin_given			=> d.pin(p).device_pin_name,
									--	cell_given			=> d.pin(p).cell_info.control_cell_id,
									--	disable_value_given	=> d.pin(p).cell_info.disable_value
									--	);
								when DH | DL | NR =>

-- 									prog_position := "UC2320";
									if p.cell_info.control_cell_shared then
										-- if driver has a shared control cell
										-- the driver pin can be disabled if its control cell is not already enabled 
										-- or targeted by atg
-- 										prog_position := "UC2330";

										-- check if control cell can be set to disable state
										if not control_cell_in_enable_state_by_any_cell_list( 
											net		=> d.name,
											class	=> d.class,
											device	=> p.device_name,
											cell_id	=> p.cell_info.control_cell_id) then

-- 											prog_position := "UC2340";
-- 											add_to_locked_control_cells_in_class_DH_DL_NR_nets(
-- 												list				=> ptr_cell_list_static_control_cells_class_DX_NR,
-- 												class_given			=> class,
-- 												level_given			=> level,
-- 												net_given			=> universal_string_type.to_bounded_string(name),
-- 												device_given		=> d.pin(p).device_name,
-- 												pin_given			=> d.pin(p).device_pin_name,
-- 												cell_given			=> d.pin(p).cell_info.control_cell_id,
-- 												locked_to_enable_state_given	=> false, -- because this is a secondary net, the control cell
-- 																						-- must be in disable state
-- 												disable_value_given				=> d.pin(p).cell_info.disable_value
-- 												);

											-- because this is a secondary net, the control cell must be in disable state
											append(list_of_static_control_cells_class_DX_NR,(
												locked_to_enable_state	=> false, 
												level					=> d.level,																					 
												class					=> d.class,
												net						=> to_bounded_string(d.name),
												device					=> p.device_name,
												pin						=> p.pin,
												id						=> p.cell_info.control_cell_id,
												disable_value			=> p.cell_info.disable_value));
										end if; -- check if control cell can be set to disable state

									else 
										-- driver has a non-shared control cell
										-- so there is no need to check cell lists 
										-- all control cells of those nets must be in disable state

-- 										add_to_locked_control_cells_in_class_DH_DL_NR_nets(
-- 											list				=> ptr_cell_list_static_control_cells_class_DX_NR,
-- 											class_given			=> class,
-- 											level_given			=> level,
-- 											net_given			=> universal_string_type.to_bounded_string(name),
-- 											device_given		=> d.pin(p).device_name,
-- 											pin_given			=> d.pin(p).device_pin_name,
-- 											cell_given			=> d.pin(p).cell_info.control_cell_id,
-- 											locked_to_enable_state_given	=> false, -- because this is a secondary net, the control cell
-- 																					-- must be in disable state
-- 											disable_value_given				=> d.pin(p).cell_info.disable_value
-- 											);

										-- because this is a secondary net, the control cell must be in disable state
										append(list_of_static_control_cells_class_DX_NR,(
											locked_to_enable_state	=> false, 
											level					=> d.level,																					 
											class					=> d.class,
											net						=> to_bounded_string(d.name),
											device					=> p.device_name,
											pin						=> p.pin,
											id						=> p.cell_info.control_cell_id,
											disable_value			=> p.cell_info.disable_value));
										
									end if; -- if driver has a shared control cell

								when PU | PD =>
									if p.cell_info.control_cell_shared then
										-- if driver has a shared control cell
										-- the driver pin can be disabled if its control cell is not already enabled 
										-- or targeted by atg

										-- check if control cell can be set to disable state
										if not control_cell_in_enable_state_by_any_cell_list( 
											net		=> d.name,
											class	=> d.class,
											device	=> p.device_name,
											cell_id	=> p.cell_info.control_cell_id) then

-- 											add_to_locked_control_cells_in_class_PU_PD_nets(
-- 												list				=> ptr_cell_list_static_control_cells_class_PX,
-- 												class_given			=> class,
-- 												level_given			=> level,
-- 												net_given			=> universal_string_type.to_bounded_string(name),
-- 												device_given		=> d.pin(p).device_name,
-- 												pin_given			=> d.pin(p).device_pin_name,
-- 												cell_given			=> d.pin(p).cell_info.control_cell_id,
-- 												--locked_to_enable_state_given	=> false, -- because this is a secondary net, the control cell
-- 																						-- must be in disable state
-- 												disable_value_given				=> d.pin(p).cell_info.disable_value
-- 												);

											-- because this is a secondary net, the control cell must be in disable state
											append(list_of_static_control_cells_class_PX,(
												level					=> d.level,																					 
												class					=> d.class,
												net						=> to_bounded_string(d.name),
												device					=> p.device_name,
												pin						=> p.pin,
												id						=> p.cell_info.control_cell_id,
												disable_value			=> p.cell_info.disable_value));
											
										end if;  -- check if control cell can be set to disable state

									else 
										-- driver has a non-shared control cell
										-- so there is no need to check cell lists 
										-- all control cells of those nets must be in disable state

-- 										add_to_locked_control_cells_in_class_PU_PD_nets(
-- 											list				=> ptr_cell_list_static_control_cells_class_PX,
-- 											class_given			=> class,
-- 											level_given			=> level,
-- 											net_given			=> universal_string_type.to_bounded_string(name),
-- 											device_given		=> d.pin(p).device_name,
-- 											pin_given			=> d.pin(p).device_pin_name,
-- 											cell_given			=> d.pin(p).cell_info.control_cell_id,
-- 											--locked_to_enable_state_given	=> false, -- because this is a secondary net, the control cell
-- 																					-- must be in disable state
-- 											disable_value_given				=> d.pin(p).cell_info.disable_value
-- 											);

										-- because this is a secondary net, the control cell must be in disable state
										append(list_of_static_control_cells_class_PX,(
											level					=> d.level,																					 
											class					=> d.class,
											net						=> to_bounded_string(d.name),
											device					=> p.device_name,
											pin						=> p.pin,
											id						=> p.cell_info.control_cell_id,
											disable_value			=> p.cell_info.disable_value));
									
									end if; -- if driver has a shared control cell

							end case;
						end if;
					when primary => -- because it is about secondary nets here
						null;
-- 						prog_position := "UC2400";
				end case;

			end if; -- if pin is scan capable
		end loop;

		-- FIND SUITABLE DRIVER PIN BEGIN:
		-- It will be searched for only one driver !
		case d.level is
			when primary => -- search driver in primary nets only
				case d.class is -- search in these net classes only
					when DH | DL | NR | PU | PD =>
						-- FIND ALL OUTPUT PINS WITHOUT DISABLE SPEC
						-- if there is such a pin, it is to be preferred over other drivers
						drivers_without_disable_spec_ct := 0; -- reset counter for drivers without disable spec
						for i in 1..length(d.pins) loop -- loop through pin list of given net
							p := element(d.pins, positive(i));
							if p.is_bscan_capable then -- care for scan capable pins only
								-- if pin has no disable spec. (means: no control cell)
								if p.cell_info.output_cell_id /= -1 and p.cell_info.control_cell_id = -1 then
									case d.class is
										when DH | DL =>
-- 											add_to_locked_output_cells_in_class_DH_DL_nets(
-- 												list				=> ptr_cell_list_static_output_cells_class_DX_NR,
-- 												class_given			=> class,
-- 												net_given			=> universal_string_type.to_bounded_string(name),
-- 												device_given		=> d.pin(p).device_name,
-- 												pin_given			=> d.pin(p).device_pin_name,
-- 												cell_given			=> d.pin(p).cell_info.output_cell_id,
-- 												drive_value_given	=> drive_value_derived_from_class(class)
-- 												);
										
											append(list_of_static_output_cells_class_DX_NR,(
												level					=> d.level,																					 
												class					=> d.class,
												net						=> to_bounded_string(d.name),
												device					=> p.device_name,
												pin						=> p.pin,
												id						=> p.cell_info.control_cell_id,
												drive_value				=> drive_value_derived_from_class(d.class));
										
										when NR =>

-- 											add_to_atg_drive(
-- 												list				=> ptr_cell_list_atg_drive,
-- 												class_given			=> class,
-- 												net_given			=> universal_string_type.to_bounded_string(name),
-- 												device_given		=> d.pin(p).device_name,
-- 												pin_given			=> d.pin(p).device_pin_name,
-- 												cell_given			=> d.pin(p).cell_info.output_cell_id,
-- 												controlled_by_control_cell_given	=> false -- controlled by output cell
-- 												-- example: class NR primary_net LED7 device IC303 pin 2 output_cell 7
-- 												);

											append(list_of_atg_drive_cells,(
												class						=> d.class,
												net							=> to_bounded_string(d.name),
												device						=> p.device_name,
												pin							=> p.pin,
												id							=> p.cell_info.control_cell_id,
												controlled_by_control_cell	=> false);

										when others => 
-- 											prog_position := "UC2650";
											raise constraint_error; -- CS: this should never happen, special message required
									end case; -- class

									p.cell_info.selected_as_driver := true; -- mark driver as active
									-- CS: CAUTION ! MAKE SURE ATG SYNCRONIZES THOSE DRIVERS !
									drivers_without_disable_spec_ct := drivers_without_disable_spec_ct + 1;

								end if;
							end if; -- if pin is scan capable
						end loop; -- loop through pin list of given net

						-- if output pin without disable spec found, other drivers must be found and disabled
						if drivers_without_disable_spec_ct > 0 then
-- 							if debug_level >= 30 then
-- 								put_line(standard_output, positive'image(drivers_without_disable_spec_ct) & " driver(s) with non-shared control cell found in net " & universal_string_type.to_string(d.name));
-- 							end if;
							if drivers_without_disable_spec_ct > 1 then
								put_line(standard_output, message_error & "Common mode drivers are not supported currently !"); -- CS
								raise constraint_error;
							end if;
							disable_remaining_drivers(d); -- disable left over drivers in net where d points to
						else 
						-- NO OUTPUT PIN WITHOUT DISABLE SPEC FOUND
						-- FIND ONE DRIVER WITH NON-SHARED CONTROL CELL

-- 							if debug_level >= 30 then
-- 								put_line(standard_output," searching driver with non-shared control cell in net " & universal_string_type.to_string(d.name));
-- 							end if;

						for i in 1..length(d.pins) loop loop -- loop through pin list of given net -- CS: use a variable that holds the pin count of the net
							p := element(d.pins, positive(i));
								if p.is_bscan_capable then -- care for scan capable pins only
									-- if pin has output cell with disable spec. (means: there is a control cell)
									if p.cell_info.output_cell_id /= -1 and p.cell_info.control_cell_id /= -1 then
										-- select non-shared control cells

										if not p.cell_info.control_cell_shared then

											case class is
												when DH | DL =>
													-- add control cell to list (no need to check cell lists, as this control cell is non-shared)
													prog_position := "UC2830";
													add_to_locked_control_cells_in_class_DH_DL_NR_nets(
														list				=> ptr_cell_list_static_control_cells_class_DX_NR,
														class_given			=> class,
														level_given			=> level,
														net_given			=> universal_string_type.to_bounded_string(name),
														device_given		=> d.pin(p).device_name,
														pin_given			=> d.pin(p).device_pin_name,
														cell_given			=> d.pin(p).cell_info.control_cell_id,
														locked_to_enable_state_given	=> true, -- the pin is to be enabled
														enable_value_given				=> negate_bit_character_class_0(d.pin(p).cell_info.disable_value)
														);

													-- add output cell to list
													prog_position := "UC2840";
													add_to_locked_output_cells_in_class_DH_DL_nets(
														list				=> ptr_cell_list_static_output_cells_class_DX_NR,
														class_given			=> class,
														net_given			=> universal_string_type.to_bounded_string(name),
														device_given		=> d.pin(p).device_name,
														pin_given			=> d.pin(p).device_pin_name,
														cell_given			=> d.pin(p).cell_info.output_cell_id,
														drive_value_given	=> drive_value_derived_from_class(class)
														);

												when NR =>
													-- add control cell to list
													prog_position := "UC2850";
													add_to_locked_control_cells_in_class_DH_DL_NR_nets(
														list				=> ptr_cell_list_static_control_cells_class_DX_NR,
														class_given			=> class,
														level_given			=> level,
														net_given			=> universal_string_type.to_bounded_string(name),
														device_given		=> d.pin(p).device_name,
														pin_given			=> d.pin(p).device_pin_name,
														cell_given			=> d.pin(p).cell_info.control_cell_id,
														locked_to_enable_state_given	=> true, -- the pin is to be enabled
														enable_value_given				=> negate_bit_character_class_0(d.pin(p).cell_info.disable_value)
														);
													
													-- add output cell to list
													prog_position := "UC2860";
													add_to_atg_drive(
														list				=> ptr_cell_list_atg_drive,
														class_given			=> class,
														net_given			=> universal_string_type.to_bounded_string(name),
														device_given		=> d.pin(p).device_name,
														pin_given			=> d.pin(p).device_pin_name,
														cell_given			=> d.pin(p).cell_info.output_cell_id,
														controlled_by_control_cell_given	=> false -- controlled by output cell
														-- example: class NR primary_net LED7 device IC303 pin 2 output_cell 7
														);

												when PU | PD =>
													-- add output cell to list
													-- NOTE: in pull-up/down nets, the output cell of the driver is static
													prog_position := "UC2870";
													add_to_locked_output_cells_in_class_PU_PD_nets(
														list				=> ptr_cell_list_static_output_cells_class_PX,
														class_given			=> class,
														net_given			=> universal_string_type.to_bounded_string(name),
														device_given		=> d.pin(p).device_name,
														pin_given			=> d.pin(p).device_pin_name,
														cell_given			=> d.pin(p).cell_info.output_cell_id,
														drive_value_given	=> drive_value_derived_from_class(class)
														-- example: class PU primary_net /SYS_RESET device IC300 pin 39 output_cell 37 locked_to drive_value 0
														);

													-- add control cell to list
													-- NOTE: in pull-up/down nets, the control cell of the driver is dynamic (means ATG controlled)
													prog_position := "UC2880";
													add_to_atg_drive(
														list				=> ptr_cell_list_atg_drive,
														class_given			=> class,
														net_given			=> universal_string_type.to_bounded_string(name),
														device_given		=> d.pin(p).device_name,
														pin_given			=> d.pin(p).device_pin_name,
														cell_given			=> d.pin(p).cell_info.control_cell_id,
														controlled_by_control_cell_given	=> true, -- controlled by control cell
														control_cell_inverted_given	=> inverted_status_derived_from_class_and_disable_value(
																							class_given => class,
																							disable_value_given => d.pin(p).cell_info.disable_value
																							)
														-- example: -- class PU primary_net /CPU_WR device IC300 pin 26 control_cell 6 inverted yes
														);

												when others => 
													prog_position := "UC2890"; -- in EL and EH nets, no driver is to be searched for
													-- this code should never be reached
											end case;

											prog_position := "UC2900";
											d.pin(p).cell_info.selected_as_driver := true; -- mark driver as active
											driver_with_non_shared_control_cell_found := true;
											exit; -- no more driver search required


										end if; -- if non-shared control cell
									end if; -- if pin has output and control cell
								end if; -- if pin is scan capable
							end loop; -- loop through pin list of given net

							prog_position := "UC3000";
							if driver_with_non_shared_control_cell_found then
								prog_position := "UC3100";
								if debug_level >= 30 then
									put_line(standard_output,"   driver with non-shared control cell found in net " & universal_string_type.to_string(d.name));
								end if;
								disable_remaining_drivers(d); -- disable left over drivers in net where d points to
							else
							-- NO OUTPUT PIN WITHOUT NON-SHARED CONTROL CELL FOUND
							-- FIND DRIVER WITH SHARED CONTROL CELL

								-- FOR PU/PD NETS, WITHOUT SPECIAL THREATMENT, ABORT HERE
								-- pull-nets require a driver with a fully independed control cell
								prog_position := "UC3200";
								if class = PU or class = PD then
									put_line(standard_output,"ERROR: Shared control cell conflict ! No suitable driver pin found in class " 
										& type_net_class'image(class) & " net '" & name & "' !.");
									put_line(standard_output,"Class PU or PD nets require a driver with a fully independed control cell !");
									-- CS: refine error output
									raise constraint_error;
								end if;

-- 								if debug_level >= 30 then
-- 									put_line(standard_output," searching driver with shared control cell in net " & universal_string_type.to_string(d.name));
-- 								end if;


								for p in 1..d.part_ct loop -- loop through pin list of given net
									if d.pin(p).is_bscan_capable then -- care for scan capable pins only
										-- if pin has output cell with disable spec. (means: there is a control cell)
										prog_position := "UC3210";
										if d.pin(p).cell_info.output_cell_id /= -1 and d.pin(p).cell_info.control_cell_id /= -1 then

											-- care for shared control cells only
											if d.pin(p).cell_info.control_cell_shared then

												case class is
													when DH | DL | NR =>
														-- the driver pin can be used if its control cell is not already disabled 
														-- or targeted by atg
														-- so the cell lists must be checked
														prog_position := "UC3220";
														if not control_cell_in_disable_state_by_any_cell_list( 
															net		=> d.name,
															class	=> class,
															device	=> d.pin(p).device_name,
															cell_id	=> d.pin(p).cell_info.control_cell_id) then

															-- the driver pin can be used as driver, its control cell is not in use by atg and not in disable state

															-- add control cell to list
															prog_position := "UC3230";
															add_to_locked_control_cells_in_class_DH_DL_NR_nets(
																list				=> ptr_cell_list_static_control_cells_class_DX_NR,
																class_given			=> class,
																level_given			=> level,
																net_given			=> universal_string_type.to_bounded_string(name),
																device_given		=> d.pin(p).device_name,
																pin_given			=> d.pin(p).device_pin_name,
																cell_given			=> d.pin(p).cell_info.control_cell_id,
																locked_to_enable_state_given	=> true, -- the pin is to be enabled
																enable_value_given				=> negate_bit_character_class_0(d.pin(p).cell_info.disable_value)
																);

															case class is
																when DH | DL =>
																	-- add output cell to list
																	prog_position := "UC3240";
																	add_to_locked_output_cells_in_class_DH_DL_nets(
																		list				=> ptr_cell_list_static_output_cells_class_DX_NR,
																		class_given			=> class,
																		net_given			=> universal_string_type.to_bounded_string(name),
																		device_given		=> d.pin(p).device_name,
																		pin_given			=> d.pin(p).device_pin_name,
																		cell_given			=> d.pin(p).cell_info.output_cell_id,
																		drive_value_given	=> drive_value_derived_from_class(class)
																		);

																when NR =>
																	-- add output cell to list
																	prog_position := "UC3250";
																	add_to_atg_drive(
																		list				=> ptr_cell_list_atg_drive,
																		class_given			=> class,
																		net_given			=> universal_string_type.to_bounded_string(name),
																		device_given		=> d.pin(p).device_name,
																		pin_given			=> d.pin(p).device_pin_name,
																		cell_given			=> d.pin(p).cell_info.output_cell_id,
																		controlled_by_control_cell_given	=> false
																		);
																when others => -- should never happen
																	prog_position := "UC3260";
																	raise constraint_error; 
															end case;

															d.pin(p).cell_info.selected_as_driver := true; -- mark driver as active
															driver_with_shared_control_cell_found := true;
															exit; -- no more driver search required

														end if; -- if control_cell_in_any_cell_list

													when others => -- should never happen
														prog_position := "UC3270";
														raise constraint_error; 

												end case; -- class

											end if; -- if shared control cell
										end if; -- if pin has output and control cell
									end if; -- if pin is scan capable
								end loop; -- loop through pin list of given net

								-- abort if no driver with shared control cell found
								prog_position := "UC3280";
								if not driver_with_shared_control_cell_found then
									put_line(standard_output,"ERROR: Shared control cell conflict ! No suitable driver pin found in class " 
										& type_net_class'image(class) & " net '" & name & "' !.");
									raise constraint_error;
								end if;
							end if; -- if driver_with_non_shared_control_cell_found
						end if; -- if driver without disable spec found

					when others => prog_position := "UC3290"; -- class EH | EL does not require searching for any driver pins
				end case; -- class

			when others => prog_position := "UC3300"; -- secondary nets never have any drivers enabled
		end case; -- level
	end update_cell_lists;

	
	

	procedure dump_net_content ( -- CS: receive the net as full type type_net
	-- from a given net name, the whole content (means all devices) is dumped into the preliminary data base
		name 				: in type_net_name.bounded_string; 
		level 				: in type_net_level; 

		-- for secondary nets, the superordinated primary net is taken here. otherwise the default is ""
		-- this argument is required for writing cell lists, where reference to primary nets is required
		primary_net_is		: in type_net_name.bounded_string := type_net_name.to_bounded_string("");

		class 				: in type_net_class; 
		spacing_from_left 	: in positive
		) is
		d : type_net;
		p : type_pin;


	begin -- dump_net_content for net name given in "name"
		-- net name "name" is passed from superordinated procedure make_new_net_list when calling this procedure
		-- marks the net as "optimized"
		-- fetches net content from data base net list pointed to by pointer d
		-- updates cell lists using cell info from net pointed to by d
		-- 		while d /= null loop -- loop through net list taken from uut data base
		for i in 1..length(list_of_nets) loop
			d := element(list_of_nets, positive(i));

			-- on match of net name: means, the net given from make_new_net_list has been found in data base net list pointed to by d
			if d.name = name then

				-- mark this net as optimized by chkpsn
				-- later, it helps to distinguish non-optimzed nets which must be dumped into the preliminary data base too
				d.optimized := true;

				-- loop through part list of the net
				-- and dump the net content like "IC301 ? XC9536 PLCC-S44 2  pb00_00 | 107 bc_1 input x | 106 bc_1 output3 x 105 0 z"
				-- into the preliminary data base
				for i in 1..length(d.pins) loop
					p := element(d.pins, positive(i));
					-- dump the standard segment like "IC301 ? XC9536 PLCC-S44 2"
					put(spacing_from_left*row_separator_0 & to_string(p.device_name)
						& row_separator_0 & type_device_class'image(p.device_class)
						& row_separator_0 & to_string(p.device_value)
						& row_separator_0 & to_string(p.device_package)
						& row_separator_0 & to_string(p.device_pin_name)
					);
					if p.is_bscan_capable then
						-- dump the input cell segment like "| 107 bc_1 input x "
						put(row_separator_0 & to_string(p.device_port_name));
						if p.cell_info.input_cell_id /= -1 then
							put(row_separator_1 & trim(natural'image(p.cell_info.input_cell_id),left)
								& row_separator_0 & type_boundary_register_cell'image(p.cell_info.input_cell_type)
								& row_separator_0 & type_cell_function'image(p.cell_info.input_cell_function)
								& row_separator_0 & type_bit_char_class_1'image(p.cell_info.input_cell_safe_value)(2)
								);
						end if;

						if p.cell_info.output_cell_id /= -1 then
							-- dump the output cell segment like "| 106 bc_1 output3"
							put(row_separator_1 & trim(natural'image(p.cell_info.output_cell_id),left)
								& row_separator_0 & type_boundary_register_cell'image(p.cell_info.output_cell_type)
								& row_separator_0 & type_cell_function'image(p.cell_info.output_cell_function)
								& row_separator_0 & type_bit_char_class_1'image(p.cell_info.output_cell_safe_value)(2)
								);

							if p.cell_info.control_cell_id /= -1 then
								-- dump the contol cell segment like "x 105 0 z"
								put(row_separator_0 & trim(natural'image(p.cell_info.control_cell_id),left)
									& row_separator_0 & type_bit_char_class_0'image(p.cell_info.disable_value)(2)
									& row_separator_0 & type_disable_result'image(p.cell_info.disable_result)
									);
							end if;
						end if;
					else -- pin is not scan capable, but it might have a port name (linkage pins of bic)
						if to_string(p.device_port_name) /= "" then
							put(row_separator_0 & to_string(p.device_port_name));
						end if;
					end if;
					new_line; -- line finished, add line break for next line
				end loop; -- loop through part list of the net
				-- net content dumping completed

				-- now that d points to the net in data base net list, the new cell list can be updated regarding this net
				update_cell_lists( d ); -- so we pass pointer d

				exit; -- no need to search other nets in data base
			end if;
-- 			d := d.next; -- advance net pointer to next net
		end loop;
	end dump_net_content;

	
	

	procedure make_new_net_list is
		-- with the two net lists pointed to by net_ptr and options_net_ptr, a new net list is created and appended to the
		-- preliminary data base
		-- the class requirements and secondary net dependencies from the options file are taken into account
		o	: type_options_net;
		n 	: type_net;

	begin -- make_new_net_list
	-- reads options net list pointed to by pointer o
	-- writes a structure as shown below in the preliminary data base:
	
--> header:	SubSection LED1 class NR

--> by procedure dump_net_content:
-- 		RN302 '?' 2k7 SIL8 4
-- 		JP402 '?' MON1 2X20 22
-- 		IC303 '?' SN74BCT8240ADWR SOIC24 9 y2(3) | 1 BC_1 OUTPUT3 X 16 1 Z
-- 		D402 '?' none LED5MM K
--> footer:	EndSubSection
--> footer:	SubSection secondary_nets_of LED1
-- 
--> header: SubSection LED1_R class NR
--> by procedure dump_net_content:
-- 			RN302 '?' 2k7 SIL8 3
-- 			JP402 '?' MON1 2X20 28
-- 			IC301 '?' XC9536 PLCC-S44 3 pb00_01 | 104 BC_1 INPUT X | 103 BC_1 OUTPUT3 X 102 0 Z
--> footer:	EndSubSection
--> footer: EndSubSection secondary_nets_of LED1

		-- 		while o /= null loop -- o points to options net list
		for i in 1..length(list_of_options_nets) loop
			o := element(list_of_options_nets, positive(i));
			new_line;
			-- write primary net header like "SubSection LED0 class NR" (name and class taken from options net list)
			put_line(column_separator_0);
			put_line(row_separator_0 & section_mark.subsection & row_separator_0 & to_string(o.name) & row_separator_0 
				& text_udb_class & row_separator_0 & type_net_class'image(o.class));

			-- this is a primary net. it will be searched for in the net list and its content dumped into the preliminary data base
			put_line("  -- name class value package pin"
				& " [ port | in_cell: id type func safe | out_cell: id type func safe [ ctrl_cell id disable result ]]");
			dump_net_content( -- CS: send full type_net
				name => o.name, 
				level => primary,
				class => o.class,
				spacing_from_left => 2
				);

			-- put end of primary net mark
			put_line(row_separator_0 & section_mark.endsubsection);

			-- if there are secondary nets specified in options net list, dump them one by one into the preliminary data base
			if o.has_secondaries then
				put_line(row_separator_0 & section_mark.subsection & row_separator_0 netlist_keyword_header_secondary_nets & row_separator_0 & to_string(o.name));
				new_line;
				for s in 1..length(o.list_of_secondary_net_names) loop
					put_line(2*row_separator_0 & section_mark.subsection & row_separator_0 
						& to_string(element(o.list_of_secondary_net_names, positive(s))
						& row_separator_0 & text_udb_class & type_net_class'image(o.class)
						);

					dump_net_content(
						name => to_string(element(o.list_of_secondary_net_names, positive(s))),
						level => secondary,
						primary_net_is => o.name, -- required for writing some cell lists where reference to primary net is required
						class => o.class, 
						spacing_from_left => 4
						);
					put_line(2*row_separator_0 & section_mark.endsubsection);
					new_line;
				end loop;
				put_line(row_separator_0 & section_mark.endsubsection & row_separator_0 netlist_keyword_header_secondary_nets &
						 row_separator_0 & to_string(o.name));
				put_line(column_separator_0);
				new_line;
			end if;

-- 			o := o.next;
		end loop;

		-- dump non-optimized nets 
		-- they have the "optimized" flag cleared (false) and default to level primary with class NA
		-- pointer n points to data base net list
		put_line(column_separator_0);
		put_line("-- NON-OPTIMIZED NETS ---------------------------");
		put_line(column_separator_0);

		-- 		while n /= null loop -- n points to data base net list
		for i in 1..length(list_of_nets) loop -- CS: use summary instead ?
			n := element(list_of_nets, positive(i));
			--put_line(universal_string_type.to_string(n.name));
			if not n.optimized then -- if non-optimized
				--put_line(prog_position);
				new_line;
				-- write primary net header like "SubSection LED0 class NR" (name and class taken from options net list)
				put_line(column_separator_0);
				put_line(row_separator_0 & section_mark.subsection & row_separator_0 & to_string(n.name) & row_separator_0 
					& text_udb_class & row_separator_0 & type_net_class'image(NA));

				-- this is a primary net. it will be searched for in the net list and its content dumped into the preliminary data base
				dump_net_content(
					name => n.name, 
					level => primary,
					class => NA,
					spacing_from_left => 2
					);

				-- put end of primary net mark
				put_line(row_separator_0 & section_mark.endsubsection);
			end if;
-- 			n := n.next;
		end loop;
	end make_new_net_list;


	procedure write_new_cell_lists is
		a : type_static_control_cell_class_EX_NA;
		b : type_static_control_cell_class_DX_NR;
		c : type_static_control_cells_class_PX;
		d : type_static_output_cells_class_PX;
		e : type_static_output_cells_class_DX_NR;
		f : type_static_expect_cell;
		g : type_atg_expect_cell;
		h : type_atg_drive_cell;
		i : type_input_cell_class_NA;
	begin
		put_line("------- CELL LISTS ----------------------------------------------------------");
		new_line(2);

		--put_line("Section locked_control_cells_in_class_EH_EL_NA_nets"); -- CS: Section locked_control_cells_in_class_EH_EL_?_nets discarded
		put_line(section_mark.section & row_separator_0 & section_static_control_cells_class_EX_NA);
		-- writes a cell list entry like:
		put_line("-- addresses control cells which statically disable drivers");
		put_line("-- example 1: class NA primary_net OSC_OUT device IC300 pin 6 control_cell 93 locked_to disable_value 0");
		put_line("-- example 2: class NA secondary_net OSC_OUT device IC300 pin 6 control_cell 93 locked_to disable_value 0");
		--while a /= null loop
		for cc in 1..length(list_of_static_control_cells_class_EX_NA) loop
			a := element(list_of_static_control_cells_class_EX_NA, positive(cc));
			put_line(" class " & type_net_class'image(a.class) & row_separator_0 & to_lower(type_net_level'image(a.level)) & "_net"
				& row_separator_0 & to_string(a.net) & " device"
				& row_separator_0 & to_string(a.device) & " pin"
				& row_separator_0 & to_string(a.pin) & " control_cell" & natural'image(a.cell)
				& " locked_to disable_value " & type_bit_char_class_0'image(a.disable_value)(2) -- strip "'" delimiters
				);
		end loop;
		put_line(section_mark.endsection); new_line;

		--put_line("Section locked_control_cells_in_class_DH_DL_NR_nets");
		put_line(section_mark.section & row_separator_0 & section_static_control_cells_class_DX_NR);
		-- writes a cell list entry like:
		put_line("-- addresses control cells which enable or disable static drivers");
		put_line("-- example 1: class NR primary_net LED0 device IC303 pin 10 control_cell 16 locked_to enable_value 0");
		put_line("-- example 2: class NR primary_net LED1 device IC303 pin 9 control_cell 16 locked_to enable_value 0");
		put_line("-- example 3: class NR secondary_net LED7_R device IC301 pin 13 control_cell 75 locked_to disable_value 0");
		--while b /= null loop
		for cc in 1..length(list_of_static_control_cells_class_DX_NR) loop
			b := element(list_of_static_control_cells_class_DX_NR, positive(cc));
			put(" class " & type_net_class'image(b.class) & row_separator_0 & to_lower(type_net_level'image(b.level)) & "_net"
				& row_separator_0 & to_string(b.net) & " device"
				& row_separator_0 & to_string(b.device) & " pin"
				& row_separator_0 & to_string(b.pin) & " control_cell" & natural'image(b.cell)
				& " locked_to ");
			case b.locked_to_enable_state is
				when true 	=> put_line("enable_value " & type_bit_char_class_0'image(b.enable_value)(2)); -- strip "'" delimiters
				when false	=> put_line("disable_value " & type_bit_char_class_0'image(b.disable_value)(2)); -- strip "'" delimiters
			end case;
-- 			b := b.next;
		end loop;
		put_line(section_mak.endsection); new_line;

		--put_line("Section locked_control_cells_in_class_PU_PD_nets");
		put_line(section_mark.section & row_separator_0 & section_static_control_cells_class_PX);
		-- writes a cell list entry like:
		put_line("-- addresses control cells which statically disable drivers");
		put_line("-- example 1: class PD primary_net PD1 device IC301 pin 7 control_cell 87 locked_to disable_value 0");
		--put_line("-- example 2: class PD primary_net PD1 device IC301 pin 7 control_cell 87 locked_to enable_value 0");
		put_line("-- example 2: class PD secondary_net PD1 device IC301 pin 7 control_cell 87 locked_to disable_value 0");
-- 		while c /= null loop
		for cc in 1..length(list_of_static_control_cells_class_PX) loop
			c := element(list_of_static_control_cells_class_PX, positive(cc));
			put(" class " & type_net_class'image(c.class) & row_separator_0 & to_lower(type_net_level'image(c.level)) & "_net"
				& row_separator_0 & to_string(c.net) & " device"
				& row_separator_0 & to_string(c.device) & " pin"
				& row_separator_0 & to_string(c.pin) & " control_cell" & natural'image(c.cell)
				& " locked_to ");
			put_line("disable_value " & type_bit_char_class_0'image(c.disable_value)(2)); -- strip "'" delimiters
-- 			c := c.next;
		end loop;
		put_line(section_mark.endsection); new_line;

		--put_line("Section locked_output_cells_in_class_PU_PD_nets");
		put_line(section_mark.section & row_separator_0 & section_static_output_cells_class_PX);
		-- writes a cell list entry like:
		put_line("-- addresses output cells which drive statically");
		put_line("-- example 1 : class PU primary_net /SYS_RESET device IC300 pin 39 output_cell 37 locked_to drive_value 0");
		put_line("-- example 2 : class PD primary_net SHUTDOWN device IC300 pin 4 output_cell 375 locked_to drive_value 1");
-- 		while d /= null loop
		for cc in 1..length(list_of_static_output_cells_class_PX) loop
			d := element(list_of_static_output_cells_class_PX, positive(cc));
			put_line(" class " & type_net_class'image(d.class) & " primary_net"
				& row_separator_0 & to_string(d.net) & " device"
				& row_separator_0 & to_string(d.device) & " pin"
				& row_separator_0 & to_string(d.pin) & " output_cell" & natural'image(d.cell)
				& " locked_to drive_value " & type_bit_char_class_0'image(d.drive_value)(2));
-- 			d := d.next;
		end loop;
		put_line(section_mark.endsection); new_line;

		--put_line("Section locked_output_cells_in_class_DH_DL_nets");
		put_line(section_mark.section & row_separator_0 & section_static_output_cells_class_DX_NR);
		-- writes a cell list entry like:
		put_line("-- addresses output cells which drive statically");
		put_line("-- example 1 : class DL primary_net /CPU_MREQ device IC300 pin 28 output_cell 13 locked_to drive_value 0");
		put_line("-- example 2 : class DH primary_net /CPU_RD device IC300 pin 27 output_cell 10 locked_to drive_value 1");
		put_line("-- NOTE:   1 : Output cells of disabled driver pins may appear here. Don't care.");
-- 		while e /= null loop
		for cc in 1..length(list_of_static_output_cells_class_DX_NR) loop
			e := element(list_of_static_output_cells_class_DX_NR, positive(cc));
			put_line(" class " & type_net_class'image(e.class) & " primary_net"
				& row_separator_0 & to_string(e.net) & " device"
				& row_separator_0 & to_string(e.device) & " pin"
				& row_separator_0 & to_string(e.pin) & " output_cell" & natural'image(e.cell)
				& " locked_to drive_value " & type_bit_char_class_0'image(e.drive_value)(2));
-- 			e := e.next;
		end loop;
		put_line(section_mark.endsection); new_line;

		--put_line("Section static_expect");
		put_line(section_mark.section & row_separator_0 & section_static_expect);
		-- writes a cell list entry like:
		put_line("-- addresses input cells which expect statically");
		put_line("-- example 1 : class DL primary_net /CPU_MREQ device IC300 pin 28 input_cell 14 expect_value 0");
		put_line("-- example 2 : class DH secondary_net MREQ device IC300 pin 28 input_cell 14 expect_value 1 primary_net_is MR45");
-- 		while f /= null loop
		for cc in 1..length(list_of_static_expect_cells) loop
			f := element(list_of_static_expect_cells, positive(cc));
			put(" class " & type_net_class'image(f.class) & row_separator_0 & to_lower(type_net_level'image(f.level)) & "_net"
				& row_separator_0 & to_string(f.net) & " device"
				& row_separator_0 & to_string(f.device) & " pin"
				& row_separator_0 & to_string(f.pin) & " input_cell" & natural'image(f.cell)
				& " expect_value " & type_bit_char_class_0'image(f.expect_value)(2)); -- strip "'" delimiters
			if f.level = secondary then
				put_line(" primary_net_is " & to_string(f.primary_net_is));
			else new_line;
			end if;
-- 			f := f.next;
		end loop;
		put_line(section_mark.endsection); new_line;

		--put_line("Section atg_expect");
		put_line(section_mark.section & row_separator_0 & section_atg_expect);
		-- writes a cell list entry like:
		put_line("-- addresses input cells which expect values defined by ATG");
		put_line("-- example 1 : class PU secondary_net CT_D3 device IC303 pin 19 input_cell 11 primary_net_is D3");
		put_line("-- example 2 : class PU primary_net /CPU_WR device IC300 pin 26 input_cell 8");
-- 		while g /= null loop
		for cc in 1..length(list_of_atg_expect_cells) loop
			g := element(list_of_atg_expect_cells, positive(cc));
			put(" class " & type_net_class'image(g.class) & row_separator_0 & to_lower(type_net_level'image(g.level)) & "_net"
				& row_separator_0 & to_string(g.net) & " device"
				& row_separator_0 & to_string(g.device) & " pin"
				& row_separator_0 & to_string(g.pin) & " input_cell" & natural'image(g.cell));
			case g.level is
				when secondary =>
					put_line(" primary_net_is " & to_string(g.primary_net_is));
				when primary =>
					new_line;
			end case;
-- 			g := g.next;
		end loop;
		put_line(section_mark.endsection); new_line;

		--put_line("Section atg_drive");
		put_line(section_mark.section & row_separator_0 & section_atg_drive);
		-- writes a cell list entry like:
		put_line("-- addresses output and control cells which drive values defined by ATG");
		put_line("-- example 1 : class NR primary_net LED7 device IC303 pin 2 output_cell 7");
		put_line("-- example 2 : class PU primary_net /CPU_WR device IC300 pin 26 control_cell 6 inverted yes");
		put_line("-- example 3 : class PD primary_net /DRV_EN device IC301 pin 27 control_cell 9 inverted no");
-- 		while h /= null loop
		for cc in 1..length(list_of_atg_drive_cells) loop
			h := element(list_of_atg_drive_cells, positive(cc));
			put(" class " & type_net_class'image(h.class) & " primary_net"
				& row_separator_0 & to_string(h.net) & " device"
				& row_separator_0 & to_string(h.device) & " pin"
				& row_separator_0 & to_string(h.pin));
			case h.controlled_by_control_cell is
				when true =>
					put(" control_cell" & natural'image(h.cell) & " inverted ");
					if h.inverted then put_line("yes");
					else put_line("no");
					end if;
				when false =>
					put_line(" output_cell"  & natural'image(h.cell));
			end case;
-- 			h := h.next;
		end loop;
		put_line(section_mark.endsection); new_line;

		--put_line("Section input_cells_in_class_NA_nets"); -- CS: input_cells_in_class_?_nets discarded
		put_line(section_mark.section & row_separator_0 & section_input_cells_class_NA);
		-- writes a cell list entry like:
		put_line("-- addresses input cells");
		put_line("-- example 1 : class NA primary_net OSC_OUT device IC301 pin 6 input_cell 95");
		put_line("-- example 2 : class NA secondary_net LED0_R device IC301 pin 2 input_cell 107 primary_net_is LED0");
-- 		while i /= null loop
		for cc in 1..length(list_of_input_cells_class_NA) loop
			i := element(list_of_input_cells_class_NA, positive(cc));
			put(" class NA " & to_lower(type_net_level'image(i.level)) & "_net"
				& row_separator_0 & to_string(i.net) & " device"
				& row_separator_0 & to_string(i.device) & " pin"
				& row_separator_0 & to_string(i.pin) & " input_cell" & natural'image(i.cell));
			case i.level is
				when secondary =>
					put_line(" primary_net_is " & to_string(i.primary_net_is));
				when primary =>
					new_line;
			end case;
-- 			i := i.next;
		end loop;
		put_line(section_mark.endsection); new_line;

		--put_line(column_separator_0);
	end write_new_cell_lists;


	procedure write_new_statistics is -- CS: use predefined statistics_indentifiers_xxx here
	begin
		put_line("------- STATISTICS ----------------------------------------------------------");
		new_line;
		put_line(section_mark.section & row_separator_0 & "statistics");
		put_line("---------------------------------------------------");
 		put_line(" ATG-drivers   (dynamic) :" & natural'image(summary.net_count_statistics.atg_drivers));
 		put_line(" ATG-receivers (dynamic) :" & natural'image(summary.net_count_statistics.atg_receivers));
		put_line("---------------------------------------------------");
		put_line(" Pull-Up nets        (PU):" & natural'image(summary.net_count_statistics.pu));
 		put_line(" Pull-Down nets      (PD):" & natural'image(summary.net_count_statistics.pd));
 		put_line(" Drive-High nets     (DH):" & natural'image(summary.net_count_statistics.dh));
 		put_line(" Drive-Low nets      (DL):" & natural'image(summary.net_count_statistics.dl));
 		put_line(" Expect-High nets    (EH):" & natural'image(summary.net_count_statistics.eh));
 		put_line(" Expect-Low nets     (EL):" & natural'image(summary.net_count_statistics.el));
 		put_line(" unrestricted nets   (NR):" & natural'image(summary.net_count_statistics.nr));
 		put_line(" not classified nets (NA):" & natural'image(summary.net_count_statistics.na));
		put_line("---------------------------------------------------");
 		put_line(" total                   :" & natural'image(summary.net_count_statistics.total));
		put_line("--------------------------------------------------");
 		put_line(" bs-nets static          :" & natural'image(summary.net_count_statistics.bs_static));
 		put_line(" thereof :");
   		put_line("   bs-nets static L      :" & natural'image(summary.net_count_statistics.bs_static_l));
   		put_line("   bs-nets static H      :" & natural'image(summary.net_count_statistics.bs_static_h));
 		put_line(" bs-nets dynamic         :" & natural'image(summary.net_count_statistics.bs_dynamic));
 		put_line(" bs-nets testable        :" & natural'image(summary.net_count_statistics.bs_testable));
		put_line("---------------------------------------------------");
		put_line(section_mark.endsection);
	end write_new_statistics;

-------- MAIN PROGRAM ------------------------------------------------------------------------------------

begin
	new_line;
	put_line("primary/secondary/class builder "& version);
	put_line("=======================================");
	prog_position := "ARG001";
	name_file_database := to_bounded_string(argument(1));
	put_line (text_identifier_database & "     : " & to_string(name_file_database));
	name_file_database_backup := name_file_database; -- backup name of database. used for overwriting data base with temporarily data base

	prog_position := "ARG002";
	name_file_options := to_bounded_string(argument(2));
	put_line ("options file   : " & to_string(name_file_options));

	prog_position := "ARG003";
	if argument_count = 3 then
-- 		debug_level := natural'value(argument(3));
		-- 		put_line ("debug level    :" & natural'image(debug_level));
		-- CS: degree of integrity check
	end if;

	-- make backup of given udb
	
	-- recreate an empty tmp directory
	prog_position := "TMP001";
	create_temp_directory;

	prog_position := "RDB001";
	read_uut_data_base;
	

	-- open options file
	prog_position := "OPT001";
	open( 
		file => file_options,
		mode => in_file,
		name => to_string(name_file_options)
		);

	-- read options file
	-- check if primary net incl. secondary nets may change class as specified in options file
	-- if class rendering allowed, add primary net with its secondary nets to options net list
	-- this is achieved at prog_position OP5300 by procedure add_to_options_net_list
	-- ptr_options_net points to generated options net list
	prog_position := "OPT005";
	put_line("reading options file ...");
	set_input(file_options); -- set data source
	while not end_of_file
		loop
			prog_position := "OP5000";
			line_counter := line_counter + 1;
			line_of_file := remove_comment_from_line(to_bounded_string(get_line));

			if get_field_count(to_string(line_of_file)) > 0 then -- if line contains anything
				if primary_net_section_entered then
					-- we are inside primary net section

					if secondary_net_section_entered then
						-- we are inside secondary net section

						-- wait for end of secondary net section mark
						if get_field_from_line(to_string(line_of_file),1) = section_mark.endsubsection then
							secondary_net_section_entered := false;
							if secondary_net_count = 0 then
								put_line(message_warning & "Primary net '" & to_string(name_of_current_primary_net) 
									& "' has an empty secondary net subsection !");
							end if;

						-- count secondary nets and collect them in array list_of_secondary_net_names
						--if to_upper(get_field_from_line(line_of_file,1)) = type_options_net_identifier'image(net) then
						elsif to_upper(get_field_from_line(to_string(line_of_file),1)) = type_options_net_identifier'image(net) then
							secondary_net_count := secondary_net_count + 1;
							--list_of_secondary_net_names(secondary_net_count) := universal_string_type.to_bounded_string(get_field_from_line(line_of_file,2));
							append(list_of_secondary_net_names, to_bounded_string(get_field_from_line(to_string(line_of_file),2));
						else
							prog_position := "OP5100";
 							put_line(message_error & "Keyword '" & type_secondary_net_name_identifier'image(net) & "' or '"
								& section_mark.endsubsection & "' expected !");
 							raise constraint_error;
						end if;
					else
						-- wait for end of primary net section
						if get_field_from_line(to_string(line_of_file),1)) = section_mark.endsection then
							primary_net_section_entered := false;

-- 							-- when end of primary net section reached:
-- 							if debug_level >= 10 then
-- 								new_line;
-- 								put_line("primary net name    : " & extended_string.to_string(name_of_current_primary_net));
-- 								put_line("primary net class   : " & type_net_class'image(class_of_current_primary_net));
-- 								if secondary_net_count > 0 then
-- 									put_line("secondary net count :" & natural'image(secondary_net_count));
-- 									put("secondary nets      : ");
-- 									for s in 1..secondary_net_count loop
-- 										put(universal_string_type.to_string(list_of_secondary_net_names(s)) & row_separator_0);
-- 									end loop;
-- 									new_line;
-- 								end if;
-- 							end if;

							-- ask if the primary net (incl. secondary nets) may become member of class specified in options file
							-- if class request can be fulfilled, add net to options net list
							prog_position := "OP5200";
							if query_render_net_class (
								primary_net_name => name_of_current_primary_net,
								primary_net_class => class_of_current_primary_net,
								list_of_secondary_net_names	=> list_of_secondary_net_names,
								secondary_net_count	=> secondary_net_count
								) then 
									prog_position := "OP5300";
									add_to_options_net_list(
										name_given							=> name_of_current_primary_net,
										class_given							=> class_of_current_primary_net,
										line_number_given					=> line_number_of_primary_net_header,
										list_of_secondary_net_names_given	=> list_of_secondary_net_names
									);
									
							end if;
							secondary_net_count := 0; -- reset secondary net counter for next primary net
							-- CS: purge list_of_secondary_net_names ?

						-- if not secondary_net_section_entered yet, wait for "SubSection secondary_nets" header
						-- if "SubSection secondary_nets" found, set secondary_net_section_entered flag
						elsif get_field_from_line(to_string(line_of_file),1)) = section_mark.subsection and
							to_upper(get_field_from_line(to_string(line_of_file),2)) = type_secondary_nets_section_identifier'image(secondary_nets) then
								secondary_net_section_entered := true;
						else
							prog_position := "OP5400";
 							put_line(message_error & "Keywords '" & section_mark.subsection 
								& " " & type_secondary_nets_section_identifier'image(secondary_nets)
								& "' or '" & section_mark.endsection
								& "' expected !");
 							raise constraint_error;
						end if;
					end if;


				-- if primary net section not entered, wait for primary net header like "Section LED0 class NR", 
				-- then set "primary net section entered" flag
				elsif get_field_from_line(to_string(line_of_file),1)) = section_mark.section then
					name_of_current_primary_net := to_bounded_string(get_field_from_line(to_string(line_of_file),2));
					if to_upper(get_field_from_line(to_string(line_of_file),3)) = type_options_class_identifier'image(class) then
						null; -- fine
					else
						prog_position := "OP5500";
						put_line(message_error & "Identifier '" & type_options_class_identifier'image(class) & "' expected after primary net name !");
						raise constraint_error;
					end if;
					class_of_current_primary_net := type_net_class'value(get_field_from_line(to_string(line_of_file),4));
					primary_net_section_entered := true;
					line_number_of_primary_net_header := line_counter; -- backup line number of net header
					-- when adding the net to the net list, this number goes into the list as well
				else
					prog_position := "OP5600";
					put_line(message_error & "Keyword '" & section_mark.section & "' expected !");
					raise constraint_error;
				end if;

			end if;

		end loop;

	prog_position := "OPT100";
	set_input(standard_input);
	prog_position := "OPT105";
	close(file_options);
	-- options net list ready. pointer options_net_ptr points to list !
	-- data base net list ready, pointer net_ptr points to list !

-- CS: It's too confusing outputting statistics at this stage. So this block is commented.
-- CS: compare net numbers ?
--	put_line("comparing net count");
--	if total_options_net_count < udb_summary.net_count_statistics.total then
--		put_line("WARNING: Number of nets found in options file differs from number those in data base !");
--		put_line("options net count   : " & natural'image(total_options_net_count));

		--put_line("data base net count : " & natural'image(udb_summary.net_count_statistics.bs_testable));
		-- it makes not sense to output number of bs_testable, because chkpsn runs on a newly generated udb (made by mknets).
		-- a brand new udb has all nets in class NA, hence there are no bs_testable nets (if judged by net classes)

--		put_line("data base net count : " & natural'image(udb_summary.net_count_statistics.total));
--	end if;

	-- extract from current udb the sections "scanpath_configuration" and "registers" in preliminary data base
	prog_position := "EX0000";
	create( file_database_preliminary, name => 
		compose (name_directory_temp, "preliminary_" & to_string(name_file_database) );
	--set_output( data_base_file_preliminary); -- set data sink

	-- open data base file
	prog_position := "EX0500";
	open( 
		file => file_database,
		mode => in_file,
		name => to_string(name_file_database)
		);

	set_input(file_database); -- set data source
	set_output(file_database_preliminary); -- set data sink
	prog_position := "EX1000";
	line_counter := 0;
	while line_counter <= summary.line_number_end_of_section_registers
		loop
			prog_position := "EX2000";
			line_counter := line_counter + 1;
			line_of_file := to_bounded_string(get_line);
			prog_position := "EX2100";
			put_line(to_string(line_of_file));
		end loop;
	prog_position := "EX2200";
	set_input(standard_input);
	close(file_database);


	prog_position := "NL1000";
	put_line(section_mark.section & row_separator_0 & section_netlist);
	put_line(column_separator_0);
	put_line("-- modified by primary/secondary/class builder version " & version);
	put_line("-- date: " & date_now & " (YYYY-MM-DD HH:MM:SS)");
	--new_line(2);
	prog_position := "NL2000";

	-- with the two netlists pointed to by net_ptr and options_net_ptr, a new net list is created and appended to the
	-- preliminary data base
	-- the class requirements and secondary net dependencies from the options file are taken into account
	make_new_net_list;

	put_line(section_mark.endsection);
	new_line(2);

	prog_position := "NL3000";
	write_new_cell_lists;

	--put_line(column_separator_1);

	prog_position := "NL4000";
	set_output(standard_output);
	close(file_database_preliminary);

	-- check preliminary data base and obtain summary
	put_line("parsing preliminary " & text_identifier_database & "...");
	name_file_database := to_bounded_string(name_directory_temp, "preliminary_" & to_string(name_file_database));
	read_uut_data_base;
	-- summary now available in summary

	-- reopen preliminary data base in append mode
	prog_position := "ST1000";
	open( 
		file => file_database_preliminary,
		mode => append_file,
		name => to_string(name_file_database)
		);
	set_output(file_database_preliminary);
	write_new_statistics;
	close(file_database_preliminary);

	-- overwrite now useless old data base with temporarily data base
	prog_position := "ST1100";
	copy_file(to_string(name_file_database), to_string(name_file_database_backup));
	-- clean up tmp directory
	prog_position := "ST1200";
	delete_file(to_string(name_file_database));

	exception

		when event: others =>
			set_exit_status(failure);
			set_output(standard_output);

			if prog_position = "ARG001" then
				put_line(message_error & text_identifier_database & " file missing or insufficient access rights !");
				put_line("       Provide " text_identifier_database & " name as argument. Example: chkpsn my_uut.udb");

			elsif prog_position = "ARG002" then
				put_line(message_error & "Options file missing or insufficient access rights !");
				put_line("       Provide options file as argument. Example: chkpsn my_uut.udb my_options.opt");

			else
-- 				put("unexpected exception: ");
				put_line(exception_name(event));
				put(exception_message(event)); new_line;
				put_line("program error at position " & prog_position);
					--put_line("ERROR in options file in line :" & natural'image(line_counter));
					--clean_up;
					--raise;
			end if;

end chkpsn;
