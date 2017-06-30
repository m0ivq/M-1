------------------------------------------------------------------------------
--                                                                          --
--                    SYSTEM M-1 MODULE IMPKICAD                            --
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
--   NOTE: This importer has been tested with kicad v4
--
--   history of changes:
--
--	TODO: See comments starting with "CS". CS means "construction side"
--		Issue #1: Kicad exports nets for unconnected pins which is in general a good idea.
--				  But, pin_count (used for later statistics) increments on every pin. So pin_count
--				  does not represent the exact number of connected pins (see header in skeleon file)

with ada.text_io;				use ada.text_io;
with ada.characters;			use ada.characters;
with ada.characters.latin_1;	use ada.characters.latin_1;
with ada.characters.handling;	use ada.characters.handling;

with ada.strings;				use ada.strings;
with ada.strings.bounded; 		use ada.strings.bounded;
with ada.strings.unbounded; 	use ada.strings.unbounded;
with ada.strings.fixed; 		use ada.strings.fixed;
with ada.strings.maps;			use ada.strings.maps;
with ada.containers;            use ada.containers;
with ada.containers.vectors;
with ada.exceptions; 			use ada.exceptions;

with ada.command_line;			use ada.command_line;
with ada.directories;			use ada.directories;

with m1_base;					use m1_base;
with m1_import;					use m1_import;
with m1_database;               use m1_database;
with m1_numbers;                use m1_numbers;
with m1_files_and_directories;  use m1_files_and_directories;
with m1_string_processing;		use m1_string_processing;


procedure impkicad is

	version			: constant string (1..3) := "001";
    prog_position	: natural := 0;

	use type_net_name;
	use type_device_name;
	use type_device_value;
	use type_package_name;
	use type_pin_name;
	use type_map_of_nets;
	use m1_import.type_list_of_pins;
	use type_map_of_devices;

	use type_name_file_netlist;
	use type_universal_string;
	use type_name_file_skeleton_submodule;

	-- IMPORTANT: This importer ready netlists of version D.
	type type_netlist_version is (D); -- other netlist versions ?
	netlist_version : type_netlist_version := D;

	
	line_counter : natural := 0; -- the line number in the given kicad netlist file

	-- These are section names used in the kicad netlist. Since some of them conflict with 
	-- already reserved GNAT keywords, we prepend a prefix "cmd_".
	cmd_prefix : constant string (1..4) := "cmd_";
	type type_command is (
		cmd_export,
		cmd_version,
		cmd_design,		
		cmd_source,
		cmd_date,
		cmd_tool,
		cmd_sheet,
		cmd_number,
		cmd_name,
		cmd_tstamps,
		cmd_title_block,
		cmd_title,
		cmd_company,
		cmd_rev,
		cmd_comment,
		cmd_value,
		cmd_components,
		cmd_comp,
		cmd_ref,
		cmd_footprint,
		cmd_libsource, cmd_lib, cmd_part,
		cmd_sheetpath, cmd_names,
        cmd_tstamp,
        cmd_libparts, cmd_libpart,
        cmd_description,
        cmd_footprints, cmd_fp,
        cmd_fields, cmd_field,
        cmd_pins, cmd_pin, cmd_num, cmd_type,
        cmd_libraries, cmd_library, cmd_logical, cmd_uri,
        cmd_nets, cmd_net, cmd_code, cmd_node
		);
	
	procedure read_netlist is
	-- Reads the given netlist file.

		-- Round brackets are used throuhout the netlist in order to nest
		-- sections:
		ob : constant character := '(';
		cb : constant character := ')';

		-- Here we define the set of characters that terminate a command or an argument.
		--char_seq : constant string (1..4) := latin_1.space & latin_1.ht & latin_1.lf & ')'; -- no need any more
		-- When a line has been fetched from file the horizontal tabs are replaced by space.
		-- Line-feeds are already removed by get_line. So we have to watch out for
		-- characters space and ')'.
		term_char_seq : constant string (1..2) := latin_1.space & ')';
		term_char_set : character_set := to_set(term_char_seq);

		line : unbounded_string; -- the line being processed
		cursor : natural; -- the position of the cursor

		-- instantiate the command stack. 
		-- We assume there is no deeper hierarchy than 20 currently. CS: increase if necessary.
		package command_stack is new stack_lifo(max => 20, item => type_command);
        --use command_stack;

		procedure get_next_line is
		-- Fetches a new line. 
		-- Replaces all horizontal tabs by spaces.
		-- Increments line_counter.
		begin
			--new_line;
			line_counter := line_counter + 1;
			line := to_unbounded_string( translate(get_line,ht_to_space'access) );
			--put_line("line" & positive'image(line_counter) & "->" & to_string(line) & "<-");
		end get_next_line;
		
		procedure p1 is
		-- Updates the cursor position to the position of the next
		-- non_space character starting from the current cursor position.
		-- Fetches a new line if no further characters after current cursor position.
		begin
			cursor := index_non_blank(source => line, from => cursor + 1);
			while cursor = 0 loop
				get_next_line;
				cursor := index_non_blank(source => line, from => cursor + 1);
			end loop;
			--put_line("cursor at pos of next char" & natural'image(cursor));	
		end p1;

		-- These flags should be used when processing sections. Currently they are not used. CS
-- 		entered_export, 
-- 		entered_version,
-- 		entered_design,		-- not used
-- 		entered_source,		-- not used
-- 		entered_date,		-- not used
-- 		entered_tool,		-- not used
-- 		entered_sheet,		-- not used
-- 		entered_number,		-- not used
-- 		entered_name,		-- not used
-- 		entered_tstamps,	-- not used
-- 		entered_title_block,-- not used
-- 		entered_title,		-- not used
-- 		entered_company,	-- not used
-- 		entered_rev,		-- not used
-- 		entered_comment,	-- not used
-- 		entered_value,		-- not used
-- 		entered_components,	-- not used
-- 		entered_comp,		-- not used
-- 		entered_ref,		-- not used
-- 		entered_value,		-- not used
-- 		entered_footprint	-- not used
-- 		entered_libsource,	-- not used
--		entered_sheetpath,	-- not used
--		entered_tstamp,		-- not used
-- 					: boolean := false;


		cmd : type_command;
		arg : unbounded_string; -- here the argument goes finally

		-- These are scratch variables used when reading devices, pins and nets:
		device_name	: type_device_name.bounded_string;
		device		: type_device;
		net_name    : type_net_name.bounded_string;
		pin			: m1_import.type_pin;
		list_of_pins: m1_import.type_list_of_pins.vector;
		net			: m1_import.type_net;

		function strip_prefix (cmd : in type_command) return string is
		-- Removes the prefix from given command and returns the command as lowercase string.
		begin
			return to_lower( type_command'image(cmd)
				(
				cmd_prefix'length+1 			-- from character after cmd_prefix
				..								-- to
				type_command'image(cmd)'length	-- last character of cmd
				)); 
		end strip_prefix;

		procedure write_pinlist is
		-- Dumps the list_of_pins.
			pin : m1_import.type_pin;
		begin
			put_line(" with pins:");
			if length(list_of_pins) > 0 then
				for p in 1..positive(length(list_of_pins)) loop
					pin := element(list_of_pins, p);
					put_line("  device " & to_string(pin.name_device) 
						& " pin " & to_string(pin.name_pin));
				end loop;
			end if;
		end write_pinlist;
		
		procedure verify_cmd is
		-- Verifies if command is allowed at this level. CS
		-- Verifies if command is among allowed subcommands. CS
		
			--level : natural := command_stack.depth;

			procedure error_on_invalid_level is
			begin
				put_line(message_error & "line" 
					& positive'image(line_counter) & " : "
					& "keyword '"
					& strip_prefix(cmd) & "'"
					& " not allowed in this level");
				raise constraint_error;
			end error_on_invalid_level;

		begin -- verify_cmd
			case cmd is

-- 				when cmd_export => 
-- 					if depth = 1 then
-- 						entered_export := true;
-- 					else
-- 						error_on_invalid_level;
-- 					end if;

				when cmd_components =>
-- 					if depth = 2 then
-- 						entered_components := true;
						put_line("reading devices ...");
-- 					else
-- 						error_on_invalid_level;
-- 					end if;

				when cmd_nets =>
						put_line("reading nets ...");


				when others => null;

			end case;
		end verify_cmd;


		procedure read_cmd is 
		-- Reads the command from current cursor position until termination
		-- character or its last character.
		-- Stores the command on command_stack.
			end_of_cmd : integer;  -- may become negative if no terminating character present
		begin
			--put_line("cmd start at: " & natural'image(cursor));

			-- get position of last character
			end_of_cmd := index(source => line, from => cursor, set => term_char_set) -1;

			-- if no terminating character found, end_of_cmd assumes length of line
			if end_of_cmd = -1 then
				end_of_cmd := length(line);
			end if;

			--put_line("cmd end at  : " & positive'image(end_of_cmd));

			-- Compose command from cursor..end_of_cmd.
			-- This is an implicit general test whether the command is a valid keyword.
			cmd := type_command'value( cmd_prefix & slice(line,cursor,end_of_cmd) );

			-- update cursor
			cursor := end_of_cmd;

			-- save command on stack
			command_stack.push(cmd);

			verify_cmd;

 			--put_line("LEVEL" & natural'image(command_stack.depth)); 
			--put_line(" INIT " & strip_prefix(cmd));

			exception
                when constraint_error =>
                    write_message(
                        file_handle => file_import_cad_messages,
                        text => message_error & "line" 
                            & positive'image(line_counter) & " : "
                            & "invalid keyword '"
                            & slice(line,cursor,end_of_cmd) & "'",
                        console => true);
					raise;
		end read_cmd;

		procedure read_arg is
		-- Reads the argument of a command.
		-- Mostly the argument is separated from the command by space.
		-- Some arguments are wrapped in quotations.
		-- Leaves the cursor at the position of the last character of the argument.
		-- If the argument was enclosed in quotations the cursor is left at
		-- the position of the trailing quotation.
			end_of_arg : integer; -- may become negative if no terminating character present
		begin
			--put_line("arg start at: " & natural'image(cursor));

			-- We handle an argument that is wrapped in quotation different than
			-- a non-wrapped argument:
			if element(line, cursor) = latin_1.quotation then
				-- Read the quotation-wrapped argument (strip quotations)

				-- get position of last character (before trailing quotation)
				end_of_arg := index(source => line, from => cursor+1, pattern => 1 * latin_1.quotation) -1;

				--put_line("arg end at  : " & positive'image(end_of_arg));

				-- if no trailing quotation found -> error
				if end_of_arg = -1 then
					put_line(message_error & "line" 
						& positive'image(line_counter) & " : "
						& latin_1.quotation & " expected");
						raise constraint_error;
				end if;

				-- compose argument from first character after quotation until end_of_arg
				arg := to_unbounded_string( slice(line,cursor+1,end_of_arg) );

				-- update cursor (to position of trailing quotation)
				cursor := end_of_arg+1;
			else
				-- Read the argument from current cursor position until termination
				-- character or its last character.

				-- get position of last character
				end_of_arg := index(source => line, from => cursor, set => term_char_set) -1;

				-- if no terminating character found, end_of_arg assumes length of line
				if end_of_arg = -1 then
					end_of_arg := length(line);
				end if;

				--put_line("arg end at  : " & positive'image(end_of_arg));

				-- compose argument from cursor..end_of_arg
				arg := to_unbounded_string( slice(line,cursor,end_of_arg) );

				-- update cursor
				cursor := end_of_arg;
			end if;


		end read_arg;

		procedure exec_cmd is
		begin
			-- pop last command from stack
			-- That is the command encountered after the last opening bracket.
			-- For example: When the closing bracket of a line like "(value NetChanger)" is reached,
			-- the command popped from stack is "value".
			cmd := command_stack.pop;
			--put_line(" EXEC " & strip_prefix(cmd));

			case cmd is

			-- GENERAL STUFF
				when cmd_version =>
					netlist_version := type_netlist_version'value(to_string(arg));
					put_line("netlist version " & type_netlist_version'image(netlist_version));

			-- DEVICES
                when cmd_components =>
                    null;
					put_line("reading devices done");

				when cmd_ref =>
					--put_line(standard_output, to_string(arg));
					device_name := to_bounded_string(to_string(arg));
					pin.name_device := to_bounded_string(to_string(arg));
					
				when cmd_value =>
					--put_line(standard_output, to_string(arg));
					device.value := to_bounded_string(to_string(arg));

				when cmd_footprint =>
					--put_line(standard_output, to_string(arg));
					device.packge := to_bounded_string(to_string(arg));

				when cmd_comp =>
                    put_line(
                        " device " & to_string(device_name) 
                        & " value " & to_string(device.value)
                        & " package " & to_string(device.packge));
                        
					-- insert device in map
					type_map_of_devices.insert(
						container	=> map_of_devices,
						key			=> device_name,
						new_item	=> device);

			-- NETS
                when cmd_nets =>
                    null;
                    put_line("reading nets done");

                when cmd_name =>
                    net_name := to_bounded_string(to_string(arg));

-- 				when cmd_ref =>
-- 					pin.device_name := to_bounded_string(to_string(arg));

				when cmd_pin =>
					pin.name_pin := to_bounded_string(to_string(arg));
	
				when cmd_node =>
					-- append pin to list_of_pins and update pin_count (for statistics)
					append(list_of_pins, pin);
					pin_count := pin_count + 1;
					
				when cmd_net =>
                    put(" " & to_string(net_name));
					write_pinlist;
					
					net.pins := list_of_pins;
					
					type_map_of_nets.insert(
						container 	=> map_of_nets,
						key			=> net_name,
						new_item	=> net);

					-- clean up list_of_pins for next net
					clear(list_of_pins);
					
				when others => null;
			end case;


		end exec_cmd;
			
	begin -- read_netlist
		write_message (
			file_handle => file_import_cad_messages,
			text => "reading kicad netlist file ...",
			console => true);

		open (file => file_cad_netlist, mode => in_file, name => to_string(name_file_cad_netlist));
		set_input(file_cad_netlist);

		command_stack.init;
		get_next_line;
		cursor := index(source => line, pattern => 1 * ob);
		
		while not end_of_file loop
			
			<<label_1>>
				p1; -- cursor at pos of next char
				read_cmd; -- cursor at end of cmd
				p1; -- cursor at pos of next char
				if element(line, cursor) = ob then goto label_1; end if;
			<<label_3>>
				read_arg;
				p1;
				if element(line, cursor) /= cb then
					put_line(message_error & "line" 
						& positive'image(line_counter) & " : "
						& cb & " expected");
					raise constraint_error;
				end if;
			<<label_2>>
				exec_cmd;
				if command_stack.depth = 0 then exit; end if;
				p1;

				-- Test for cb, ob or other character:
				case element(line, cursor) is

					-- If closing bracket after argument. example: (libpart (lib conn) (part CONN_01X02)
					when cb => goto label_2;

					-- If another command at a deeper level follows. example: (lib conn)
					when ob => goto label_1;

					-- In case an argument not enclosed in brackets 
					-- follows a closing bracket. example: (field (name Reference) P)
					when others => goto label_3; 
-- 						put_line(message_error & "line" 
-- 							& positive'image(line_counter) & " : "
-- 							& cb & " or " & ob & " expected"); -- CS
-- 						raise constraint_error;
				end case;
		end loop;
		--new_line(standard_output); -- finishes the progress bar
		put_line("done");

	end read_netlist;





-------- MAIN PROGRAM ------------------------------------------------------------------------------------

begin
	action := import_cad;

	-- create message/log file	
	format_cad := kicad;
	write_log_header(version);
	
	put_line(to_upper(name_module_cad_importer_kicad) & " version " & version);
	put_line("======================================");

	direct_messages; -- directs messages to logfile. required for procedures and functions in external packages
	
	prog_position	:= 10;
	name_file_cad_netlist:= to_bounded_string(argument(1));
	
	write_message (
		file_handle => file_import_cad_messages,
		text => "netlist " & to_string(name_file_cad_netlist),
		console => true);

	prog_position	:= 20;		
	cad_import_target_module := type_cad_import_target_module'value(argument(2));
	write_message (
		file_handle => file_import_cad_messages,
		text => "target module " & type_cad_import_target_module'image(cad_import_target_module),
		console => true);
	
	prog_position	:= 30;
	if cad_import_target_module = m1_import.sub then
		target_module_prefix := to_bounded_string(argument(3));

		write_message (
			file_handle => file_import_cad_messages,
			text => "prefix " & to_string(target_module_prefix),
			console => true);
		
		name_file_skeleton_submodule := to_bounded_string(compose( name => 
			base_name(name_file_skeleton) & "_" & 
			to_string(target_module_prefix),
			extension => file_extension_text));
	end if;
	
	prog_position	:= 50;	
	read_netlist;

	--sort_netlist;
	--make_map_of_devices;

	write_skeleton (name_module_cad_importer_kicad, version);

	prog_position	:= 100;
	write_log_footer;	
	
	exception when event: others =>
		set_exit_status(failure);

		write_message (
			file_handle => file_import_cad_messages,
			text => message_error & "at program position " & natural'image(prog_position),
			console => true);
	
		if is_open(file_skeleton) then
			close(file_skeleton);
		end if;

		if is_open(file_cad_netlist) then
			close(file_cad_netlist);
		end if;

		case prog_position is
			when others =>
				write_message (
					file_handle => file_import_cad_messages,
					text => "exception name: " & exception_name(event),
					console => true);

				write_message (
					file_handle => file_import_cad_messages,
					text => "exception message: " & exception_message(event),
					console => true);
		end case;

		write_log_footer;


end impkicad;
