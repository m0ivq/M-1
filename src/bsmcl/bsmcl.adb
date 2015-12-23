-- V1.3
-- raise constraint error when subprocess failed to abort bsmcl
-- RAM dump supported
-- V1.4 
--	- various cad formats supported (altium, orcad, zuken)
--	- mkoptions requires mknets executed first -> fixed	
-- V1.5
--  - minor text output changes

-- V016
-- call to verilog model maker added

-- V020
-- kermit calls optimized. shell script bsm now obsolete

-- V021
-- opt file and net routing file bear the same name as the udb by default

with Ada.Text_IO;		use Ada.Text_IO;
with Ada.Integer_Text_IO;	use Ada.Integer_Text_IO;
with Ada.Sequential_IO;
--with System.OS_Lib;   use System.OS_Lib;
with Ada.Strings; 			use Ada.Strings;
with Ada.Strings.Bounded; 	use Ada.Strings.Bounded;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Strings.Unbounded.Text_IO; use Ada.Strings.Unbounded.Text_IO;
with Ada.Task_Identification;  use Ada.Task_Identification;
with Ada.Exceptions; use Ada.Exceptions;
 
with GNAT.OS_Lib;   	use GNAT.OS_Lib;
--with system.os_lib; -- internal
with Ada.Command_Line;	use Ada.Command_Line;
with Ada.Directories;	use Ada.Directories;
with ada.environment_variables;

--with gnat.directory_operations;
--with ada.os;
with m1;
with m1_internal; use m1_internal;

procedure bsmcl is
	Version			: String (1..3) := "022";
	--bin_dir			: String := "/opt/m-1/bin/"; -- CS: need to adapt it to the customers machine ?
--	bin_dir			: String := "/home/luno/cad/projects/m-1/bin/"; -- CS: need to adapt it to the customers machine ? -- mod v017 -- rm v020

	--report_file		: string := "test.txt";

-- 	step_mode	  	: m1_internal.step_mode_type;

	uut_dir			: Unbounded_String;
	action			: Unbounded_string;
	batch_file 		: Unbounded_string;
	test_profile 	: Unbounded_string;
	test_name  		: Unbounded_string;
	sequence_name 	: Unbounded_string;
	ram_addr   		: string (1..4) := "0000"; -- page address bits [23:8]
	data_base  		: Unbounded_string;

	target_device	: unbounded_string;
	device_package	: unbounded_string;
	device_model	: unbounded_string;

	algorithm		: unbounded_string;
	target_pin		: unbounded_string;	
	target_net		: unbounded_string;
	retry_count		: unbounded_string;
	retry_delay		: unbounded_string;
	low_time		: unbounded_string;
	high_time  		: unbounded_string;		
	toggle_count	: unbounded_string;	
   
	opt_file		: unbounded_string;
	cad_format		: unbounded_string;
	net_list		: unbounded_string;
	part_list		: unbounded_string;

	v_model			: unbounded_string; -- ins V016
--	partlist_given	: boolean;
	project_name	: unbounded_string;

	line			: unbounded_string;
	skeleton_sub 	: unbounded_string;

	key				: String (1..1) := "n";
	Result   		: Integer;
--	success			: boolean;
	prog_position	: String (1..5) := "-----";

-- 	test_failed		: constant Ada.Command_Line.Exit_Status := 12;
-- 	test_passed		: constant Ada.Command_Line.Exit_Status := 11;
-- 	test_running	: constant Ada.Command_Line.Exit_Status := 10;
-- 	test_error 		: constant Ada.Command_Line.Exit_Status := 13;
-- 	bsc_reset		: constant Ada.Command_Line.Exit_Status := 14;

	arg_ct			: natural; -- ins v020
	arg_pt			: natural := 1; -- ins v020

	universal_string_length	: natural := 100;
	package universal_string_type is new generic_bounded_length(universal_string_length); use universal_string_type;

	conf_file				: Ada.Text_IO.File_Type;
	help_file				: Ada.Text_IO.File_Type;
	home_directory			: universal_string_type.bounded_string;
	conf_directory			: string (1..5) := ".M-1/";
	conf_file_name			: string (1..8) := "M-1.conf";
	help_file_name_german	: string (1..15) := "help_german.txt";
	help_file_name_english	: string (1..16) := "help_english.txt";
	--log_file_txt			: unbounded_string := to_unbounded_string("stock_log.txt");
	directory_of_backup		: unbounded_string;
	directory_of_log		: unbounded_string;
	directory_of_binary_files	: unbounded_string;
	directory_of_enscript		: unbounded_string;
	interface_to_scan_master	: universal_string_type.bounded_string;
	base_address			: string (1..8) := "FFFFFFFF";

	row_separator			: string (1..60) := "------------------------------------------------------------";
	row_separator_double	: string (1..60) := "============================================================";



	type language_type is (german, english);
	language 	: language_type := english;

	debug_mode			: natural := 0; -- default is no debug mode

	procedure check_environment is
		previous_input	: Ada.Text_IO.File_Type renames current_input;
		line			: unbounded_string;
	begin
		-- get home variable
		prog_position := "ENV00";
		if not ada.environment_variables.exists("HOME") then
			raise constraint_error;
		else
			-- compose home directory name
			home_directory := to_bounded_string(ada.environment_variables.value("HOME")); -- this is the absolute path of the home directory
			--put_line(to_string(home_directory));
		end if;

		-- check if conf file exists	
		prog_position := "ENV10";
		if not exists ( to_string(home_directory) & '/' & conf_directory & '/' & conf_file_name ) then 
			raise constraint_error;
		else
			-- read configuration file
			Open(
				file => conf_file,
				Mode => in_file,
				Name => ( to_string(home_directory) & '/' & conf_directory & '/' & conf_file_name )
				);
			set_input(conf_file);
			while not end_of_file
			loop
				line := m1.remove_comment_from_line(get_line,"#");
				--put_line(line);

				-- get language
				if m1.get_field(line,1,' ') = "language" then 
					prog_position := "ENV20";
					language := language_type'value(m1.get_field(line,2,' '));
--					if debug_mode = 1 then 
--						put_line("language        : " & language_type'image(language));
--					end if;
				end if;

				-- get bin directory
				if m1.get_field(line,1,' ') = "directory_of_binary_files" then 
					prog_position := "ENV30";
					if m1.get_field(line,2,' ')(1) /= '/' then -- if no heading /, take this as relative to home directory
						directory_of_binary_files := to_unbounded_string(to_string(home_directory)) & '/' &
							to_unbounded_string(m1.get_field(line,2,' '));
					else -- otherwise take this as an absolute path
						directory_of_binary_files := to_unbounded_string(m1.get_field(line,2,' '));
					end if;

--					if debug_mode = 1 then 
--						put_line("directory_of_binary_files : " & to_string(directory_of_binary_files));
--					end if;
				end if;

				-- get enscript directory
				if m1.get_field(line,1,' ') = "directory_of_enscript" then 
					prog_position := "ENV40";
					if m1.get_field(line,2,' ')(1) /= '/' then -- if no heading /, take this as relative to home directory
						directory_of_enscript := to_unbounded_string(to_string(home_directory)) & '/' &
							to_unbounded_string(m1.get_field(line,2,' '));
					else -- otherwise take this as an absolute path
						directory_of_enscript := to_unbounded_string(m1.get_field(line,2,' '));
					end if;

--					if debug_mode = 1 then 
--						put_line("directory_of_enscript : " & to_string(directory_of_enscript));
--					end if;
				end if;

				-- get interface_to_scan_master
				if m1.get_field(line,1,' ') = "interface_to_scan_master" then 
					prog_position := "ENV50";
					interface_to_scan_master := to_bounded_string(m1.get_field(line,2,' ')); -- this must be an absolute path
--					if debug_mode = 1 then 
--						put_line("interface_to_scan_master : " & to_string(interface_to_scan_master));
--					end if;
				end if;


			end loop;
			close(conf_file);
		end if;

		-- check if help file exists	
		prog_position := "ENV90";
		case language is
			when german => 
				if not exists ( to_string(home_directory) & "/" & conf_directory & help_file_name_german ) then 
					put_line("ERROR : German help file missing !");
				end if;
			when english =>
				if not exists ( to_string(home_directory) & "/" & conf_directory & help_file_name_english ) then 
					put_line("ERROR : English help file missing !");
				end if;
			when others =>
				put_line("ERROR : Help file missing !");
		end case;

		if debug_mode = 1 then
			put_line(row_separator);
		end if;
		set_input(previous_input);
	end check_environment;



		function exists_netlist
			(
			-- version 1.0 / MBL
			-- verifies if given netlist exists
			netlist	: string
			) return Boolean is
			
			file_exists :	Boolean := false;
			
			begin
				put ("netlist        : ");	put(netlist); new_line;				
				
				if exists (netlist) then
					file_exists := true;
				else
					new_line;
					put("ERROR ! Netlist '"& netlist &"' not found !"); 
					new_line;
					--put ("PROGRAM ABORTED !"); new_line; new_line;
					--Abort_Task (Current_Task); -- CS: not safe
				end if;
				return file_exists;
				
			end exists_netlist;


		function exists_partlist
			(
			-- version 1.0 / MBL
			-- verifies if given partlist exists
			partlist	: string
			) return Boolean is
			
			file_exists :	Boolean := false;
			
			begin
				put ("partlist       : ");	put(partlist); new_line;				
				
				if exists (partlist) then
					file_exists := true;
				else
					new_line;
					put("ERROR ! Partlist '"& partlist &"' not found !"); 
					new_line;
					--put ("PROGRAM ABORTED !"); new_line; new_line;
					--Abort_Task (Current_Task); -- CS: not safe
				end if;
				return file_exists;
				
			end exists_partlist;



		function exists_database
			(
			-- version 1.0 / MBL
			-- verifies if given database exists
			database	: string
			) return Boolean is
			
			file_exists :	Boolean := false;
			
			begin
				put ("database       : ");	put(database); new_line;				
				
				if exists (database) then
					file_exists := true;
				else
					new_line;
					--put ("ERROR ! Database '"& database &"' not found !"); 
					put ("ERROR ! Database '"& data_base &"' does not exist ! Aborting ..."); 					
					--new_line;
					--put ("PROGRAM ABORTED !"); new_line; new_line;
					--Abort_Task (Current_Task); -- CS: not safe
				end if;
				return file_exists;
				
			end exists_database;





		function exists_optfile
			(
			-- version 1.0 / MBL
			-- verifies if given optfile exists
			optfile		: string
			) return Boolean is
			
			file_exists :	Boolean := false;
			
			begin
				put ("options file   : ");	put(optfile); new_line;				
				
				if exists (optfile) then
					file_exists := true;
				else
					new_line;
					put ("ERROR ! Options file '"& optfile &"' does not exist ! Aborting ..."); 					
				end if;
				return file_exists;
				
			end exists_optfile;




		function exists_model
			(
			-- version 1.0 / MBL
			-- verifies if given model file exists
			modelfile		: string
			) return Boolean is
			
			file_exists :	Boolean := false;
			
			begin
				put ("model file     : ");	put(modelfile); new_line;				
				
				if exists (modelfile) then
					file_exists := true;
				else
					new_line;
					put ("ERROR ! Model file '"& modelfile &"' does not exist ! Aborting ..."); 					
				end if;
				return file_exists;
				
			end exists_model;



		function exists_skeleton
			(
			-- version 1.0 / MBL
			-- verifies if given skeleton file exists
			skeleton_file : string
			) return Boolean is
			
			file_exists :	Boolean := false;
			
			begin
				put ("submodule      : ");	put(skeleton_file); new_line;				
				
				if exists (skeleton_file) then
					file_exists := true;
				else
					new_line;
					put ("ERROR ! Submodule '"& skeleton_file &"' does not exist ! Aborting ..."); 					
				end if;
				return file_exists;
				
			end exists_skeleton;



		procedure advise_next_step_cadimport
			-- version 1.0 / MBL
			(
			dummy : Boolean
			) is
			begin
				put("... done"); new_line (2);
				put("Recommended next steps :"); new_line (2);
				put("  1. Read header of file 'skeleton.txt' for warnings and import notes using a text editor."); new_line;
				put("     If you have imported CAD data of a submodule, please also look into file 'skeleton_your_submodule.txt'."); new_line;				
				put("  2. Create boundary scan nets using command: 'bsmcl mknets'"); new_line;
			end advise_next_step_cadimport;


		procedure advise_next_step_generate
			-- version 1.0 / MBL
			(
			database : String;
			testname : String
			) is
			begin
				put("... done"); new_line (2);
				put("Recommended next steps :"); new_line (2);
				put("  1. Compile generated test using command 'bsmcl compile " & database & " " & testname & "'."); new_line(2);
				put("     Following steps are optional for fine tuning:"); new_line(2);				
				put("  2. Edit generated sequence file '" & testname & "/" & testname & ".seq' with a text editor."); new_line;				
				put("     NOTE: On automatic test generation the sequence file will be overwritten !"); new_line;
				put("  3. Compile modified test using command 'bsmcl compile " & database & " " & testname & "'."); new_line;				
			end advise_next_step_generate;


		procedure advise_next_step_compile
			-- version 1.0 / MBL
			(
			--database : String;
			testname : String
			) is
			begin
				put("... done"); new_line (2);
				put("Recommended next steps :"); new_line (2);
				put("  1. Load compiled test into BSC using command 'bsmcl load " & testname & "'."); new_line;
				--put("     If you have imported CAD data of a submodule, please also look into file 'skeleton_your_submodule.txt'."); new_line;				
				--put("  2. Create boundary scan nets using command: 'bsmcl mknets'"); new_line;
			end advise_next_step_compile;


		procedure advise_next_step_load
			-- version 1.0 / MBL
			(
			--database : String;
			testname : String
			) is
			begin
				put("... done"); new_line (2);
				--put("Test '"& testname &"' ready for launch !"); new_line;
				put("Recommended next steps :"); new_line (2);
				put("  1. Launch loaded test using command 'bsmcl run " & testname & "'."); new_line;
				--put("     If you have imported CAD data of a submodule, please also look into file 'skeleton_your_submodule.txt'."); new_line;				
				--put("  2. Create boundary scan nets using command: 'bsmcl mknets'"); new_line;
			end advise_next_step_load;






begin

	new_line;
	put("M-1 Command Line Interface Version "& Version); new_line;
	put_line(row_separator_double);
	check_environment;

		
	prog_position := "CRT00";
	arg_ct :=  argument_count; -- ins v020

	action:=(to_unbounded_string(Argument(1)));

		-- make project begin
		if action = "create" then
			put ("action         : ");	put(action); new_line;			
			prog_position := "PJN00";
			project_name:=to_unbounded_string(Argument(2));
			new_line;
				
				-- launch project maker
				Spawn 
					(  
					Program_Name           => to_string(directory_of_binary_files) & "/mkproject",
					Args                   => 	(
												1=> new String'(to_string(project_name))
												-- 2=> new String'(to_string(opt_file)) 
												),
					Output_File_Descriptor => Standout,
					Return_Code            => Result
					);
				-- evaluate result
				if 
					Result = 0 then Set_Directory(to_string(project_name)); -- cd into project directory
				else
					put("ERROR while creating new project'" & project_name &"'! Aborting ..."); new_line;
					prog_position := "-----";		
					raise Constraint_Error;
			
					--put("code  : "); put(Result); new_line; Abort_Task (Current_Task); -- CS: not safe
				end if;
		end if;
		-- make project end

	-- check if working directory is a project at all
	prog_position := "PDS00";
	if exists ("proj_desc.txt") then
		put ("project        : ");  put(Containing_Directory("proj_desc.txt")); new_line;
	else
		raise constraint_error;
	end if; 



	-- check action requested by operator
	--action:=(to_unbounded_string(Argument(1)));
	put ("action         : ");	put(action); new_line;

		if action = "help" then
			case language is
				when german => 
					open(
						file => help_file,
						mode => in_file,
						name => to_string(home_directory) & "/" & conf_directory & help_file_name_german
						);
				when others =>
					open(
						file => help_file,
						mode => in_file,
						name => to_string(home_directory) & "/" & conf_directory & help_file_name_english
						);
			end case;
			set_input(help_file);

			while not end_of_file
			loop
				line := get_line;
				put_line(line);
			end loop;
			close(help_file);


		-- do nothing meaningful if project has just been created
		elsif action = "create" then 
			new_line;
			put("... done"); new_line(2);
			put("Recommended next steps :"); new_line (2);
			put("  1. Change into project directory '" & project_name & "' using command 'cd " & project_name & "'."); new_line;			
			put("  2. Edit project database '" & project_name & ".udb' according to your needs using a text editor."); new_line;
			put("  3. Import BSDL model files using command: 'bsmcl impbsdl " & project_name & ".udb'"); new_line;
			--set_directory(Containing_Directory("proj_desc.txt"));


		-- CAD import begin
		elsif action = "impcad" then
			prog_position := "ICD00";			
			cad_format:=to_unbounded_string(Argument(2));

			if cad_format = "orcad" then
				put ("CAD format     : ");	put(cad_format); new_line;
				
				-- check if netlist file exists
				prog_position := "INE00";							
				if exists_netlist(Argument(3)) then null; -- raises exception if netlist not given
				else 
					prog_position := "NLE00";	
					raise Constraint_Error;
				end if;
				
				-- launch ORCAD importer
				new_line;
				Spawn 
					(  
					Program_Name           => to_string(directory_of_binary_files) & "/cad_import/imporcad",
					Args                   => 	(
												1=> new String'(Argument(3))
--												2=> new String'(Argument(4))
												),
					Output_File_Descriptor => Standout,
					Return_Code            => Result
					);
				-- evaluate result
				if Result = 0 then advise_next_step_cadimport(true);
				else
					put("ERROR   while importing ORCAD CAD data ! Aborting ..."); new_line;
					prog_position := "-----";		
					raise Constraint_Error;
				end if;


			elsif cad_format = "altium" then
				put ("CAD format     : ");	put(cad_format); new_line;
				
				-- check if netlist file exists
				prog_position := "INE00";							
				if exists_netlist(Argument(3)) then null; -- raises exception if netlist not given
				else 
					prog_position := "NLE00";	
					raise Constraint_Error;
				end if;
				
				-- launch ALTIUM importer
				new_line;
				Spawn 
					(  
					Program_Name           => to_string(directory_of_binary_files) & "/cad_import/impaltium",
					Args                   => 	(
												1=> new String'(Argument(3))
--												2=> new String'(Argument(4))
												),
					Output_File_Descriptor => Standout,
					Return_Code            => Result
					);
				-- evaluate result
				if Result = 0 then advise_next_step_cadimport(true);
				else
					put("ERROR   while importing ALTIUM CAD data ! Aborting ..."); new_line;
					prog_position := "-----";		
					raise Constraint_Error;
				end if;




			elsif cad_format = "zuken" then
				put ("CAD format     : ");	put(cad_format); new_line;
				
				-- check if netlist file exists
				prog_position := "INE00";							
				if exists_netlist(Argument(3)) then null; -- raises exception if netlist not given
				else 
					prog_position := "NLE00";	
					raise Constraint_Error;
				end if;
				
				-- launch ZUKEN importer
				new_line;
				Spawn 
					(  
					Program_Name           => to_string(directory_of_binary_files) & "/cad_import/impzuken",
					Args                   => 	(
												1=> new String'(Argument(3))
--												2=> new String'(Argument(4))
												),
					Output_File_Descriptor => Standout,
					Return_Code            => Result
					);
				-- evaluate result
				if Result = 0 then advise_next_step_cadimport(true);
				else
					put("ERROR   while importing ZUKEN CAD data ! Aborting ..."); new_line;
					prog_position := "-----";		
					raise Constraint_Error;
				end if;




			elsif cad_format = "eagle6" then
				put ("CAD format     : ");	put(cad_format); new_line;
				
				-- check if netlist file exists
				prog_position := "INE00";							
				if exists_netlist(Argument(3)) then null; -- raises exception if netlist not given
				else 
					prog_position := "NLE00";	
					raise Constraint_Error;
				end if;
				
				-- check if partlist file exists
				prog_position := "IPA00";				
				if exists_partlist(Argument(4)) then null; -- raises exception if partlist not given 
				else 
					prog_position := "PLE00";	
					raise Constraint_Error;
				end if;


				-- launch EAGLE V6 importer
				new_line;
				Spawn 
					(  
					Program_Name           => to_string(directory_of_binary_files) & "/cad_import/impeagle6x",
					Args                   => 	(
												1=> new String'(Argument(3)),
												2=> new String'(Argument(4))
												),
					Output_File_Descriptor => Standout,
					Return_Code            => Result
					);
				-- evaluate result
				if Result = 0 then advise_next_step_cadimport(true);
				else
					put("ERROR while importing EAGLE CAD data ! Aborting ..."); new_line;
					prog_position := "-----";		
					raise Constraint_Error;
			
					--put("code : "); put(Result); new_line; Abort_Task (Current_Task); -- CS: not safe
				end if;


--			elsif cad_format = "conti1" then
--				put ("CAD format     : ");	put(cad_format); put(" (IPC-D-356A) "); new_line;					
				
				-- check if netlist file exists
--				prog_position := "INE";							
--				if exists_netlist(Argument(3)) then null; -- raises exception if netlist not given
--				else 
--					prog_position := "NLE";	
--					raise Constraint_Error;
--				end if;
				
--				begin
--					part_list:=to_unbounded_string(Argument(4)); -- raises exception if partlist not given 
-- 
-- 					exception 
-- 						when Constraint_Error => 
-- 							begin
-- 								new_line; Put("WARNING : Partlist not specified ! Proceed anyway ? (y/n) "); Get(key);
-- 								--new_line;
-- 								if key = "y" then 
-- 									partlist_given := false;
-- 									--else Abort_Task (Current_Task); -- CS: not safe
-- 								else 
-- 									prog_position := "OAT"; -- program cancelled by operator
-- 									raise Constraint_Error;
-- 								end if;
-- 							end;
-- 							
-- 				end;
-- 
-- 				begin
-- 
-- 
-- 					-- if part_list has been given, check if part_list file exists
-- 					if partlist_given = true then
-- 						
-- 						-- check if partlist file exists
-- 						prog_position := "IPA";				
-- 						if exists_partlist(Argument(4)) then null; -- raises exception if partlist not given 
-- 						else 
-- 							prog_position := "PLE";	
-- 							raise Constraint_Error;
-- 						end if;
-- 						
-- 		
-- 						-- launch IPC-D-356A importer with net- and partlist
-- 						new_line;
-- 						Spawn 
-- 							(  
-- 							Program_Name           => "/home/bsadmin/bin/bsx/impconti1",
-- 							Args                   => 	(
-- 														1=> new String'(Argument(3)),
-- 														2=> new String'(Argument(4))
-- 														),
-- 							Output_File_Descriptor => Standout,
-- 							Return_Code            => Result
-- 							);
-- 					else
-- 						-- launch IPC-D-356A importer without partlist
-- 						new_line;
-- 						Spawn 
-- 							(  
-- 							Program_Name           => "/home/bsadmin/bin/bsx/impconti1",
-- 							Args                   => 	(
-- 														1=> new String'(Argument(3))
-- 														--2=> new String'(to_string(part_list))
-- 														),
-- 							Output_File_Descriptor => Standout,
-- 							Return_Code            => Result
-- 							);
-- 					end if;
-- 
-- 					-- evaluate result
-- 					if 
-- 						Result = 0 then advise_next_step_cadimport(true);
-- 					else
-- 						put("ERROR   while importing Conti1 IPC-D-356A CAD data ! Aborting ..."); new_line;
-- 					end if;
-- 				end;
				
				
				
			else	-- if unknown CAD format
				put ("CAD format     : ");	put(cad_format); new_line;					
				prog_position := "NCF00";
				raise Constraint_Error;
			end if;
		-- CAD import end


-- ins V016 begin
		-- make verilog model begin
		elsif action = "mkvmod" then

			-- do an agrument count check only, mkvmod will do the rest
			prog_position := "ACV00";
			if argument_count /= 3 then	-- bsmcl mkvmod skeleton.txt verilog_file
				raise Constraint_Error;
			end if;
									
				-- launch verilog model maker
				Spawn 
					(  
					Program_Name           => to_string(directory_of_binary_files) & "/mkvmod",
					Args                   => 	(
												1=> new String'(argument(2)),
												2=> new String'(argument(3))
												),
					Output_File_Descriptor => Standout,
					Return_Code            => Result
					);
				-- evaluate result
				if Result = 0 then
						new_line;
						put("... done"); new_line(2);
						put("Recommended next step :"); new_line (2);
						put("  1. Edit Verilog Model according to your needs."); new_line;

				else
					put("ERROR while writing Verilog model file ! Aborting ..."); new_line;
					prog_position := "-----";		
					raise Constraint_Error;
					
					--put("code : "); put(Result); new_line; Abort_Task (Current_Task); -- CS: not safe
				end if;


		-- make verilog model end
-- ins V016 end 


		-- join netlist begin
		elsif action = "join" then
			prog_position := "JSM00";
			skeleton_sub:=to_unbounded_string(Argument(2)); -- raises exception if skeleton submodule not given

			-- check if skeleton submodule file exists
			if exists_skeleton(Argument(2)) then null; -- raises exception if skeleton not given 
			else 
				prog_position := "JSN00";
				raise Constraint_Error;
			end if;
									
			-- check if skeleton main file exists
			if exists("skeleton.txt") then null; -- raises exception if skeleton main not present
			else 
				prog_position := "SMN00";
				raise Constraint_Error;
			end if;
									
									
				-- launch netlist joiner
				Spawn 
					(  
					Program_Name           => to_string(directory_of_binary_files) & "/joinnetlist",
					Args                   => 	(
												1=> new String'(to_string(skeleton_sub))
												--2=> new String'(to_string(skeleton_sub))
												),
					Output_File_Descriptor => Standout,
					Return_Code            => Result
					);
				-- evaluate result
				if Result = 0 then
						new_line;
						put("... done"); new_line(2);
						put("Recommended next step :"); new_line (2);
						put("  1. Create boundary scan nets using command: 'bsmcl mknets'"); new_line;

				else
					put("ERROR while joining netlists ! Aborting ..."); new_line;
					prog_position := "-----";		
					raise Constraint_Error;
					
					--put("code : "); put(Result); new_line; Abort_Task (Current_Task); -- CS: not safe
				end if;
		-- join netlist end 



		-- BSDL import begin
		elsif action = "impbsdl" then
			prog_position := "IBL00";
			data_base:=to_unbounded_string(Argument(2)); -- raises exception if udb not given

			-- check if udb file exists
			if exists_database(Argument(2)) then null; -- raises exception if udb not given 
			else 
				prog_position := "DBE00";		
				raise Constraint_Error;
			end if;
									
				-- launch BSDL importer
				Spawn 
					(  
					Program_Name           => to_string(directory_of_binary_files) & "/impbsdl",
					Args                   => 	(
												1=> new String'(to_string(data_base))
												-- 2=> new String'(to_string(opt_file)) 
												),
					Output_File_Descriptor => Standout,
					Return_Code            => Result
					);
				-- evaluate result
				if Result = 0 then
						new_line;
						put("... done"); new_line(2);
						put("Recommended next step :"); new_line (2);
						put("     Import CAD data files using command: 'bsmcl impcad cad_format'"); new_line;

				else
					put("ERROR   while importing BSDL files ! Aborting ..."); new_line;
					prog_position := "-----";		
					raise Constraint_Error;
				
					--put("code : "); put(Result); new_line; Abort_Task (Current_Task); -- CS: not safe
				end if;
		-- BSDL importer end




		-- mknets begin
		elsif action = "mknets" then
			prog_position := "MKN00";
			data_base:=to_unbounded_string(Argument(2)); -- raises exception if udb not given

			-- check if udb file exists
			if exists_database(Argument(2)) then null; -- raises exception if udb not given 
			else 
				prog_position := "DBE00";		
				raise Constraint_Error;
			end if;

				-- launch mknets
				Spawn 
					(  
					Program_Name           => to_string(directory_of_binary_files) & "/mknets",
					Args                   => 	(
												1=> new String'(to_string(data_base))
												-- 2=> new String'(to_string(opt_file)) 
												),
					Output_File_Descriptor => Standout,
					Return_Code            => Result
					);
				-- evaluate result
				if 
					Result = 0 then 
						put("... done"); new_line(2);
						put("Recommended next steps :"); new_line (2);
						put("     Create options file for database '" & data_base & "' using command 'bsmcl mkoptions " & data_base & " your_target_options_file.opt'"); new_line;
						--put("  2. Edit options file according to your needs using a text editor."); new_line;
						--put("  3. Import BSDL model files using command: 'bsmcl impbsdl " & project_name & ".udb'"); new_line;
						
				else
					put("ERROR   while building bscan nets ! Aborting ..."); new_line;
					prog_position := "-----";		
					raise Constraint_Error;
					--put("code : "); put(Result); new_line; Abort_Task (Current_Task); -- CS: not safe
				end if;
		-- mknets end



		-- mkoptions begin
		elsif action = "mkoptions" then
			prog_position := "MKO00";
			data_base:=to_unbounded_string(Argument(2)); -- raises exception if udb not given

			-- check if udb file exists
			if exists_database(Argument(2)) then null; -- raises exception if udb not given 
			else 
				prog_position := "DBE00";		
				raise Constraint_Error;
			end if;

			prog_position := "OP200";
			-- ins v021 begin
			if arg_ct = 2 then
				opt_file := to_unbounded_string(base_name(to_string(data_base)) & ".opt");
			else
				opt_file:=to_unbounded_string(Argument(3)); -- NOTE: the opt file given will be created by mkoptions
			end if;
			-- ins v021 end
			--	opt_file:=to_unbounded_string(Argument(3)); -- NOTE: the opt file given will be created by mkoptions -- rm v021

				-- relaunch mknets
				Spawn 
					(  
					Program_Name           => to_string(directory_of_binary_files) & "/mknets",
					Args                   => 	(
												1=> new String'(to_string(data_base))
												-- 2=> new String'(to_string(opt_file)) 
												),
					Output_File_Descriptor => Standout,
					Return_Code            => Result
					);
				-- evaluate result
				if 
					Result = 0 then
 						put("... done"); new_line(2);
-- 						put("Recommended next steps :"); new_line (2);
-- 						put("     Create options file for database '" & data_base & "' using command 'bsmcl mkoptions " & data_base & " your_target_options_file.opt'"); new_line;
						--put("  2. Edit options file according to your needs using a text editor."); new_line;
						--put("  3. Import BSDL model files using command: 'bsmcl impbsdl " & project_name & ".udb'"); new_line;
						
				else
					put("ERROR   while building bscan nets ! Aborting ..."); new_line;
					--prog_position := "---";		
					raise Constraint_Error;
					--put("code : "); put(Result); new_line; Abort_Task (Current_Task); -- CS: not safe
				end if;


				-- launch mkoptions
				Spawn 
					(  
					Program_Name           => to_string(directory_of_binary_files) & "/mkoptions",
					Args                   => 	(
												1=> new String'(to_string(data_base)),
												2=> new String'(to_string(opt_file)) 
												),
					Output_File_Descriptor => Standout,
					Return_Code            => Result
					);
				-- evaluate result
				if 
					Result = 0 then
						put("... done"); new_line(2);
						put("Recommended next steps :"); new_line (2);
						put("  1. Edit options file '" & opt_file & "' according to your needs using a text editor."); new_line;
						put("  2. Check primary/secondary dependencies and net classes using command 'bsmcl chkpsn " & data_base & " " & opt_file & "'"); new_line;

				else
					put("ERROR while writing options file ! Aborting ..."); new_line;
					prog_position := "OP300";		
					raise Constraint_Error;
					
				end if;
		-- mkoptions end




		-- chkpsn begin
		elsif action = "chkpsn" then
			prog_position := "CP100";
			data_base:=to_unbounded_string(Argument(2));

			-- check if udb file exists
			if exists_database(Argument(2)) then null; -- raises exception if udb not given 
			else 
				prog_position := "DBE00";		
				raise Constraint_Error;
			end if;

			prog_position := "OP100";
			opt_file:=to_unbounded_string(Argument(3));

			-- check if opt_file file exists
			if exists_optfile(Argument(3)) then null; -- raises exception if opt file not given 
			else 
				prog_position := "OPE00";		
				raise Constraint_Error;
			end if;

				-- relaunch mknets
				Spawn 
					(  
					Program_Name           => to_string(directory_of_binary_files) & "/mknets",
					Args                   => 	(
												1=> new String'(to_string(data_base))
												-- 2=> new String'(to_string(opt_file)) 
												),
					Output_File_Descriptor => Standout,
					Return_Code            => Result
					);
				-- evaluate result
				if Result = 0 then put("... done"); new_line;
				else
					put("ERROR while building bscan nets ! Aborting ..."); new_line;
					prog_position := "-----";		
					raise Constraint_Error;
					--Abort_Task (Current_Task); -- CS: not safe
				end if;

				--put_line("checking classes ...");

				-- launch chkpsn  
				Spawn 
					(  
					Program_Name           => to_string(directory_of_binary_files) & "/chkpsn",
					Args                   => 	(
												1=> new String'(to_string(data_base)),
												2=> new String'(to_string(opt_file)) 
												),
					Output_File_Descriptor => Standout,
					Return_Code            => Result
					);
				-- evaluate result
				if Result = 0 then 
					put("... done"); new_line (2);
					put("Recommended next steps :"); new_line (2);
					put("  1. Now edit file setup/test_init_custom.txt with a text editor."); new_line;
					put("     to prepare your generic test init sequences."); new_line (2);
					put("  2. Generate tests using command 'bsmcl generate " & data_base & "'."); new_line;
					
				else
					put("ERROR while checking classes of primary and secondary nets ! Aborting ..."); new_line;
					prog_position := "CP200";		
					raise Constraint_Error;
					--put("code : "); put(Result); new_line; Abort_Task (Current_Task); -- CS: not safe
				end if;
		-- chkpsn end




		-- test generation begin
		elsif action = "generate" then
			prog_position := "GEN00";
			data_base:=to_unbounded_string(Argument(2));

			-- check if udb file exists
			if exists_database(Argument(2)) then null; -- raises exception if udb not given 
			else 
				prog_position := "DBE00";		
				raise Constraint_Error;
			end if;
			
			prog_position := "TPR00";
			put ("test profile   : ");
			test_profile:=to_unbounded_string(Argument(3));
			put(test_profile); new_line;
				
			if test_profile = "infrastructure" then
				prog_position := "TNA00";			
				test_name:=to_unbounded_string(Argument(4));
				put ("test name      : ");	put(test_name); new_line; new_line;
				
				-- launch infra generator
				Spawn 
					(  
					Program_Name           => to_string(directory_of_binary_files) & "/mkinfra",
					Args                   => 	(
												1=> new String'(to_string(data_base)),
												2=> new String'(to_string(test_name)) -- pass test name to bsm
												),
					Output_File_Descriptor => Standout,
					Return_Code            => Result
					);
				-- evaluate result
				if Result = 0 then advise_next_step_generate(to_string(data_base),to_string(test_name));
					
				else
					put("ERROR while generating test "& test_name &" ! Aborting ..."); new_line;
					prog_position := "-----";		
					raise Constraint_Error;
					--put("code : "); put(Result); new_line; Abort_Task (Current_Task); -- CS: not safe
				end if;

			elsif test_profile = "interconnect" then
				prog_position := "TNA00";			
				test_name:=to_unbounded_string(Argument(4));
				put ("test name      : ");	put(test_name); new_line; new_line;
				-- launch interconnect generator
				Spawn 
					(  
					Program_Name           => to_string(directory_of_binary_files) & "/mkintercon",
					Args                   => 	(
												1=> new String'(to_string(data_base)),
												2=> new String'(to_string(test_name)) -- pass test name to bsm
												),
					Output_File_Descriptor => Standout,
					Return_Code            => Result
					);
				-- evaluate result
				if Result = 0 then advise_next_step_generate(to_string(data_base),to_string(test_name));
				
				else
					put("ERROR   while generating test '"& test_name &"' ! Aborting ..."); new_line;
					prog_position := "-----";		
					raise Constraint_Error;
					--put("code : "); put(Result); new_line; Abort_Task (Current_Task); -- CS: not safe
				end if;
				

			elsif test_profile = "memconnect" then
				prog_position := "TNA00";			
				test_name:=to_unbounded_string(Argument(4));
				put ("test name      : ");	put(test_name); new_line;
				
				prog_position := "TDV00";				
				target_device:=to_unbounded_string(Argument(5));
				put ("target device  : ");	put(target_device); new_line;
				
				prog_position := "DVM00";
				device_model:=to_unbounded_string(Argument(6));
				
				-- check if model file exists
				if exists_model(Argument(6)) then null; -- raises exception if model file not given 
					else 
						prog_position := "DMN00";		
						raise Constraint_Error;
				end if;
				
				prog_position := "DPC00";
				device_package:=to_unbounded_string(Argument(7));
				put ("package        : ");	put(device_package); new_line; new_line;

				-- launch memconnect generator
				prog_position := "LMC00"; -- ins v018
				--put_line( bin_dir & "mkmemcon"); -- ins v018

				Spawn 
					(  
					Program_Name           => to_string(directory_of_binary_files) & "/mkmemcon",
					Args                   => 	(
												1=> new String'(to_string(data_base)),
 												2=> new String'(to_string(test_name)), -- pass test name to bsm
 												3=> new String'(to_string(target_device)),
 												4=> new String'(to_string(device_model)),
 												5=> new String'(to_string(device_package))
												),
					Output_File_Descriptor => Standout,
					Return_Code            => Result
					);
				--put_line(integer'image(result));
	
				-- evaluate result
				if Result = 0 then 
					prog_position := "LM000";	-- ins v018
					advise_next_step_generate(to_string(data_base),to_string(test_name));

				else
					prog_position := "LM100";	-- ins v018
					put("ERROR   while generating test "& test_name &" ! Aborting ..."); new_line;
					prog_position := "MC000";	-- mod v018
					raise Constraint_Error;
					--put("code : "); put(Result); new_line; Abort_Task (Current_Task); -- CS: not safe
				end if;



			elsif test_profile = "clock" then
				prog_position := "TNA00";			
				test_name:=to_unbounded_string(Argument(4));
				put ("test name      : ");	put(test_name); new_line;
				
				prog_position := "TDV00";					
				target_device:=to_unbounded_string(Argument(5));
				put ("target device  : ");	put(target_device); new_line;
				
				prog_position := "TPI00";				
				target_pin:=to_unbounded_string(Argument(6));
				put ("pin            : ");	put(target_pin); new_line;
				
				prog_position := "RYC00";									
				retry_count:=to_unbounded_string(Argument(7));
				put ("retry count    : ");	put(retry_count); new_line; --new_line;
				
				prog_position := "RDY00";				
				retry_delay:=to_unbounded_string(Argument(8));
				put ("retry delay    : ");	put(retry_delay); new_line; new_line;

				-- launch clock sampling generator
				Spawn 
					(  
					Program_Name           => to_string(directory_of_binary_files) & "/mkclock",
					Args                   => 	(
												1=> new String'(to_string(data_base)),
												2=> new String'(to_string(test_name)), -- pass test name to bsm
												3=> new String'("non-intrusive"),
												4=> new String'(to_string(target_device)),
												5=> new String'(to_string(target_pin)),
												6=> new String'(to_string(retry_count)),
												7=> new String'(to_string(retry_delay))
												),
					Output_File_Descriptor => Standout,
					Return_Code            => Result
					);
				-- evaluate result
				if Result = 0 then advise_next_step_generate(to_string(data_base),to_string(test_name));
				
				else
					put("ERROR: While generating test "& test_name &" ! Aborting ..."); new_line;
					prog_position := "-----";		
					raise Constraint_Error;
					
					--put("code : "); put(Result); new_line; Abort_Task (Current_Task); -- CS: not safe
				end if;



			elsif test_profile = "toggle" then
				prog_position := "TNA00";			
				test_name:=to_unbounded_string(Argument(4));
				put ("test name      : ");	put(test_name); new_line;
				
				prog_position := "TON00";				
				target_net:=to_unbounded_string(Argument(5));
				put ("target net     : ");	put(target_net); new_line;
				
				prog_position := "TCT00";									
				toggle_count:=to_unbounded_string(Argument(6));
				put ("cycle count    : ");	put(toggle_count); new_line; --new_line;
				
				prog_position := "TLT00";				
				low_time:=to_unbounded_string(Argument(7));
				put ("low time       : ");	put(low_time); new_line;

				prog_position := "THT00";				
				high_time:=to_unbounded_string(Argument(8));
				put ("high time      : ");	put(high_time); new_line; new_line;

				-- launch pin toggle generator
				Spawn 
					(  
					Program_Name           => to_string(directory_of_binary_files) & "/mktoggle",
					Args                   => 	(
												1=> new String'(to_string(data_base)),
												2=> new String'(to_string(test_name)),
												-- 3=> new String'(to_string(target_device)),
												3=> new String'(to_string(target_net)),
												4=> new String'(to_string(toggle_count)),
												5=> new String'(to_string(low_time)),
												6=> new String'(to_string(high_time))
												),
					Output_File_Descriptor => Standout,
					Return_Code            => Result
					);
				-- evaluate result
				if Result = 0 then advise_next_step_generate(to_string(data_base),to_string(test_name));
				
				else
					put("ERROR: While generating test "& test_name &" ! Aborting ..."); new_line;
					prog_position := "-----";		
					raise Constraint_Error;
					
					--put("code : "); put(Result); new_line; Abort_Task (Current_Task); -- CS: not safe
				end if;


			-- if test profile not supported
			else 
				--prog_position := "TPN";
				raise CONSTRAINT_ERROR; --Abort_Task (Current_Task); -- CS: not safe
			end if;
		-- test generation end







		-- test compilation begin
		elsif action = "compile" then

			prog_position := "CMP00";
			data_base:=to_unbounded_string(Argument(2));

			-- check if udb file exists
			if exists_database(Argument(2)) then null; -- raises exception if udb not given 
			else 
				prog_position := "DBE00";		
				raise Constraint_Error;
			end if;
						
			prog_position := "CTN00";			
			--test_name:=to_unbounded_string(Argument(3)); -- rm v020
			test_name:=to_unbounded_string(m1.strip_trailing_forward_slash(Argument(3))); -- mod v020

			put ("test name      : ");	put(test_name); new_line(2);

			-- check if test directory containing the seq file exists
			if exists (compose (to_string(test_name),to_string(test_name), "seq")) then

				-- launch compiler
				Spawn 
					(  
					Program_Name           => to_string(directory_of_binary_files) & "/compseq",
					Args                   => 	(
												1=> new String'(to_string(data_base)),
												2=> new String'(to_string(test_name)) -- pass test name to bsm
												),
					Output_File_Descriptor => Standout,
					Return_Code            => Result
					);
				-- evaluate result
				if Result = 0 then advise_next_step_compile(to_string(test_name));
				else
					put("ERROR   while compiling test "& test_name &" ! Aborting ..."); new_line;
					prog_position := "-----";		
					raise Constraint_Error;
					
					--put("code : "); put(Result); new_line; Abort_Task (Current_Task); -- CS: not safe
				end if;

			else
				prog_position := "CNE00"; 
				raise constraint_error;
			end if;
		-- test compilation end






		-- test loading begin
		elsif action = "load" then
			prog_position := "LD100";			
			--test_name:=to_unbounded_string(Argument(2)); -- rm v020
			--test_name:=to_unbounded_string(m1.strip_trailing_forward_slash(Argument(2))); -- ins v020

			if load_test 
				(
				test_name					=> m1.strip_trailing_forward_slash(Argument(2)),
				interface_to_scan_master	=> to_string(interface_to_scan_master),
				directory_of_binary_files	=> to_string(directory_of_binary_files)
				) then
				prog_position := "LD110";
			else
				prog_position := "LD120";
				set_exit_status(failure);
			end if;

			
			-- check if test exists
-- 			if exists (compose (to_string(test_name),to_string(test_name), "vec")) then
-- 				put_line ("test name      : " & test_name);
-- 				base_address := m1_internal.get_test_base_address(to_string(test_name));
-- 				put_line ("base address   : " & base_address);
-- 				new_line;
-- 				--bsm --load $name
-- 				-- load test
-- 				Spawn 
-- 					(  
-- 					--Program_Name           => to_string(directory_of_binary_files) & "/bsm",
-- 					program_name           => to_string(directory_of_binary_files) & "/kermit/loadtest",
-- 					Args                   => 	(
-- 												--1=> new String'("--load"),
-- 												1=> new string'(to_string(test_name) & '/' & to_string(test_name) & ".vec"),
-- 												--2=> new String'(to_string(test_name)) -- pass test name to bsm
-- 												2=> new string'(to_string(interface_to_scan_master)),
-- 												3=> new string'(base_address(3..6)) -- CS: currently we transfer only bits 23:8
-- 												),
-- 
-- 					Output_File_Descriptor => Standout,
-- 					Return_Code            => Result
-- 					);
-- 				-- evaluate result
-- 				if Result = 0 then advise_next_step_load(to_string(test_name));
-- 				else
-- 					prog_position := "LD300";			
-- 					put("ERROR    : Malfunction while loading '"& test_name &"' ! Aborting ..."); new_line;
-- 					put("code     :"); put(Result); new_line; 
-- 					raise constraint_error;
-- 				end if;
-- 
-- 			else 
-- 				prog_position := "LD200";			
-- 				raise constraint_error;
-- 			end if;
		-- test loading end




		-- RAM dump begin
		elsif action = "dump" then
			prog_position := "DP100";			
			ram_addr:= Argument(2); -- page address bits [23:8]

			if dump_ram
				(
				interface_to_scan_master 	=> to_string(interface_to_scan_master),
				directory_of_binary_files	=> to_string(directory_of_binary_files),
				ram_addr					=> ram_addr -- page address bits [23:8]
				) then
				prog_position := "DP110";
			else
				prog_position := "DP120";
				set_exit_status(failure);
			end if;

			
			-- view mem
-- 				Spawn 
-- 					(  
-- 					Program_Name           => to_string(directory_of_binary_files) & "/bsm",
-- 					Args                   => 	(
-- 												1=> new String'("--dump"),
-- 												2=> new String'(to_string(ram_addr)) -- pass ram address bsm
-- 												),
-- 					Output_File_Descriptor => Standout,
-- 					Return_Code            => Result
-- 					);
-- 				-- evaluate result
-- 				if Result = 0 then null; -- advise_next_step_load(to_string(test_name));
-- 				else
-- 					prog_position := "DP300";			
-- 					put("ERROR    : Malfunction while hexdumping ! Aborting ..."); new_line;
-- 					--put("code     :"); put(Result); new_line; 
-- 					raise constraint_error;
-- 				end if;

			--else 
			--	prog_position := "LD2";			
			--	raise constraint_error;
			--end if;
		-- RAM dump end


		-- RAM clear begin
		elsif action = "clear" then
			prog_position := "CLR10";
			
			if clear_ram
				(
				interface_to_scan_master 	=> to_string(interface_to_scan_master),
				directory_of_binary_files	=> to_string(directory_of_binary_files)
				) then
				prog_position := "CLR20";
				put_line("Please upload compiled tests now.");
			else
				prog_position := "CLR30";
				set_exit_status(failure);
			end if;

			--ram_addr:=to_unbounded_string(Argument(2));
			
			-- view mem
-- 				Spawn 
-- 					(  
-- 					Program_Name           => to_string(directory_of_binary_files) & "/bsm",
-- 					Args                   => 	(
-- 												1=> new String'("--clrram")
-- 												--2=> new String'(to_string(ram_addr)) -- pass ram address bsm
-- 												),
-- 					Output_File_Descriptor => Standout,
-- 					Return_Code            => Result
-- 					);
-- 				-- evaluate result
-- 				if Result = 0 then 
-- 					put_line("RAM cleared. Please upload compiled tests now.");
-- 				else
-- 					prog_position := "-----";			
-- 					put("ERROR    : Malfunction while clearing RAM ! Aborting ..."); new_line;
-- 					--put("code     :"); put(Result); new_line; 
-- 					raise constraint_error;
-- 				end if;

			--else 
			--	prog_position := "LD2";			
			--	raise constraint_error;
			--end if;
		-- RAM clear end




		-- test execution begin
		-- WAITS FOR TEST END
		elsif action = "run" then
			prog_position := "RU100";
			test_name:=to_unbounded_string(m1.strip_trailing_forward_slash(Argument(2))); -- mod v020
			if arg_ct = 3 then
				prog_position := "RU400";
				m1_internal.step_mode:= m1_internal.step_mode_type'value(Argument(3)); -- ins v019
			end if;
			
			-- check if test exists
			if exists (compose (to_string(test_name),to_string(test_name), "vec")) then
				--put ("running        : ");	put(test_name); new_line;
				put_line ("test name      : " & test_name);
				--put ("mode           : ");	put("production"); new_line; --put(run_mode); new_line; -- rm v019
				put_line ("step mode      : " & step_mode_type'image(m1_internal.step_mode)); new_line; -- ins v019

				--bsm --run $run_mode $name  #launch single test/ISP
				-- launch test
				prog_position := "RU300";
				case execute_test
					(
					test_name 					=> to_string(test_name),
					interface_to_scan_master 	=> to_string(interface_to_scan_master),
					directory_of_binary_files	=> to_string(directory_of_binary_files),
					step_mode					=> step_mode
					) is
					when pass =>
						prog_position := "RU310";
						new_line;
						put_line("Test '"& test_name &"' PASSED !");
					when fail =>
						prog_position := "RU320";
						new_line;
						put_line("Test '"& test_name &"' FAILED !");
						set_exit_status(failure);
					when not_loaded =>
						prog_position := "RU330";
						new_line;
						put_line("ERROR : Test not loaded yet. Please upload test. Then try again.");
						set_exit_status(failure);
					when others =>
						prog_position := "RU340";
						new_line;
						put_line("ERROR: Internal malfunction !");
						put_line("Test '"& test_name &"' FAILED !");
						set_exit_status(failure);
				end case;

			else 
				prog_position := "RU200";
				put_line("ERROR    : Test '"& test_name &"' does not exist !");
				raise constraint_error;
			end if;
		-- test execution end


		-- test start begin
		-- DOES NOT WAIT FOR TEST END
		-- CS: CURRENTLY THERE IS NO NEED TO DO SUCH A THING !!!
-- 		elsif action = "start" then
-- 			prog_position := "-----";
-- 			--test_name:=to_unbounded_string(Argument(2)); -- rm v020
-- 			test_name:=to_unbounded_string(m1.strip_trailing_forward_slash(Argument(2))); -- mod v020
-- 			
-- 			-- check if test exists
-- 			if exists (compose (to_string(test_name),to_string(test_name), "vec")) then
-- 				put ("running        : ");	put(test_name); new_line;
-- 				put ("mode           : ");	put("production"); new_line; --put(run_mode); new_line;
-- 				--bsm --run $run_mode $name  #launch single test/ISP
-- 				-- launch test
-- 				Spawn 
-- 					(  
-- 					Program_Name           => to_string(directory_of_binary_files) & "/bsm",
-- 					Args                   => 	(
-- 												1=> new String'("--start"),
-- 												2=> new String'("production"), --(to_string(run_mode)), -- pass run mode to bsm
-- 												3=> new String'(to_string(test_name)) -- pass test name to bsm
-- 												),
-- 					Output_File_Descriptor => Standout,
-- 					Return_Code            => Result
-- 					);
-- 				-- evaluate result
-- 				if 
-- 					Result = 0 then put("Test '"& test_name &"' is RUNNING !"); new_line;
-- 				elsif
-- 					Result = 2 then put("Test '"& test_name &"' start FAILED !"); new_line;
-- 					Set_Exit_Status(Failure);
-- 				else
-- 					prog_position := "-----";					
-- 					put("ERROR    : Malfunction while starting test '"& test_name &"' ! Aborting ..."); new_line;
-- 					put("code     :"); put(Result); new_line; 
-- 					raise constraint_error;
-- 				end if;
-- 
-- 			else 
-- 				prog_position := "RU200";
-- 				raise constraint_error;
-- 			end if;
		-- test start end



		-- query bsc status begin
		elsif action = "status" then
			prog_position := "QS100";
			--prog_position := "RU1";
			--test_name:=to_unbounded_string(Argument(2));

			if query_status
				(
				interface_to_scan_master 	=> to_string(interface_to_scan_master),
				directory_of_binary_files	=> to_string(directory_of_binary_files)
				) then
				prog_position := "QS120";
			else
				prog_position := "QS130";
				set_exit_status(failure);
			end if;

			
			-- check if test exists
			--if exists (compose (to_string(test_name),to_string(test_name), "vec")) then
			--	put ("running        : ");	put(test_name); new_line;
			--	put ("mode           : ");	put("production"); new_line; --put(run_mode); new_line;
				--bsm --run $run_mode $name  #launch single test/ISP
				-- launch test
-- 				Spawn 
-- 					(  
-- 					Program_Name           => to_string(directory_of_binary_files) & "/bsm",
-- 					Args                   => 	(
-- 												1=> new String'("--status")
-- 												--2=> new String'("production"), --(to_string(run_mode)), -- pass run mode to bsm
-- 												--3=> new String'(to_string(test_name)) -- pass test name to bsm
-- 												),
-- 					Output_File_Descriptor => Standout,
-- 					Return_Code            => Result
-- 					);
-- 				-- evaluate result
-- 				put("BSC status     : ");
-- 				case Result is
-- 					when 10 => 		put_line("Test RUNNING"); set_exit_status(test_running);
-- 					when 11 => 		put_line("Test PASSED"); set_exit_status(test_passed);
-- 					when 12 => 		put_line("Test FAILED"); set_exit_status(test_failed);
-- 					when 13 => 		put_line("Test ERROR"); set_exit_status(test_error);
-- 					when 14 => 		put_line("RESET"); set_exit_status(bsc_reset);
-- 					when others => 	put_line("UNKNOWN");new_line; put_line("ERROR    : Malfunction while BSC status query !");
-- 									put("code     :"); put(Result); new_line;
-- 									raise constraint_error;
-- 				end case;
		-- query bsc status end

		-- show firmware begin
		elsif action = "firmware" then
			prog_position := "FW000";
			if show_firmware
				(
				interface_to_scan_master	=> to_string(interface_to_scan_master),
				directory_of_binary_files	=> to_string(directory_of_binary_files)
				) then
				prog_position := "FW100";
			else
				prog_position := "FW200";
				set_exit_status(failure);
			end if;
		-- show firmware end



		-- UUT power down begin
		elsif action = "off" then
			prog_position := "SDN01";
			--prog_position := "RU1";
			--test_name:=to_unbounded_string(Argument(2));

			if shutdown
				(
				interface_to_scan_master 	=> to_string(interface_to_scan_master),
				directory_of_binary_files	=> to_string(directory_of_binary_files)
				) then
				prog_position := "SDN10";
			else
				prog_position := "SDN20";
				set_exit_status(failure);
			end if;

			
			-- check if test exists
			--if exists (compose (to_string(test_name),to_string(test_name), "vec")) then
			--	put ("running        : ");	put(test_name); new_line;
			--	put ("mode           : ");	put("production"); new_line; --put(run_mode); new_line;
				--bsm --run $run_mode $name  #launch single test/ISP
				-- launch test
-- 				Spawn 
-- 					(  
-- 					Program_Name           => to_string(directory_of_binary_files) & "/bsm",
-- 					Args                   => 	(
-- 												1=> new String'("--stop")
-- 												--2=> new String'("production"), --(to_string(run_mode)), -- pass run mode to bsm
-- 												--3=> new String'(to_string(test_name)) -- pass test name to bsm
-- 												),
-- 					Output_File_Descriptor => Standout,
-- 					Return_Code            => Result
-- 					);
-- 				-- evaluate result
-- 				if 
-- 					Result = 0 then 
-- 						put("Test stopped !"); new_line;
-- 						put("UUT has been shut down !"); new_line;
-- 						put("TAP signals disconnected !"); new_line; new_line;
-- 						put("Test FAILED !"); new_line;
-- 				else
-- 					--prog_position := "RU3";					
-- 					put("ERROR    : Malfunction while UUT shut down !"); new_line;
-- 					put("code     :"); put(Result); new_line; 
-- 					raise constraint_error;
-- 				end if;

		-- UUT power down end


-- 		-- batch execution begin
-- 		elsif action = "run_sequence" then
-- 			prog_position := "---";
-- 			sequence_name:=to_unbounded_string(Argument(2));
-- 			
-- 			-- check if sequence exists
-- 			if exists (to_string(sequence_name)) then
-- 				put ("running        : ");	put(sequence_name); new_line;
-- 
-- 				-- pass sequence_name and directory to sequence_handler
-- 				Spawn 
-- 					(  
-- 					Program_Name           => bin_dir & "sequence_handler",
-- 					Args                   => 	(
-- 												1=> new String'(Containing_Directory(to_string(sequence_name))),
-- 												2=> new String'(to_string(sequence_name))
-- 												),
-- 					Output_File_Descriptor => Standout,
-- 					Return_Code            => Result
-- 					);
-- 				-- evaluate result
-- 				if 
-- 					Result = 0 then put("test sequence '"& sequence_name &"' PASSED !"); new_line;
-- 				elsif
-- 					Result = 1 then put("test sequence '"& sequence_name &"' FAILED !"); new_line;
-- 					Set_Exit_Status(Failure);
-- 				else
-- 					prog_position := "---";					
-- 					put("ERROR    : Malfunction while executing test sequence '"& sequence_name &"' ! Aborting ..."); new_line;
-- 					put("code     :"); put(Result); new_line; 
-- 					raise constraint_error;
-- 				end if;
-- 
-- 			else 
-- 				prog_position := "---";
-- 				raise constraint_error;
-- 			end if;
-- 		-- test execution end



		-- view test report begin
		elsif action = "report" then
			prog_position := "-----";
			--test_name:=to_unbounded_string(Argument(2));
			
			-- check if test exists
			if exists ("test_sequence_report.txt") then
				--put ("creating PDF test report of "); new_line;
				put ("PDF file name  : ");	put(Containing_Directory("proj_desc.txt") & "/test_sequence_report.pdf"); new_line;
				
				-- convert report txt file to pdf
				Spawn 
					(  
					Program_Name           => to_string(directory_of_enscript) & "/enscript", -- -p last_run.pdf last_run.txt",
					Args                   => 	(
												1=> new String'("-p"),
												2=> new String'("test_sequence_report.pdf"),
												3=> new String'("test_sequence_report.txt")
												),
					Output_File_Descriptor => Standout,
					Return_Code            => Result
					);
				-- evaluate result
				if 
					Result = 0 then put("done"); new_line;
				elsif
					Result = 1 then put("FAILED !"); new_line;
					Set_Exit_Status(Failure);
				else
					prog_position := "-----";					
-- 					put("ERROR    : Malfunction while executing test '"& test_name &"' ! Aborting ..."); new_line;
-- 					put("code     :"); put(Result); new_line; 
					raise constraint_error;
				end if;


				-- open pdf report
				Spawn 
					(  
					Program_Name           => 	to_string(directory_of_binary_files) & "/open_report", -- "/usr/bin/okular", -- -p last_run.pdf last_run.txt",
					Args                   => 	(
												1=> new String'("test_sequence_report.pdf")
												--2=> new String'("1>/dev/null") -- CS: suppress useless output of okular
												--3=> new String'("last_run.txt")
												),
					Output_File_Descriptor => Standout,
					Return_Code            => Result
					);
				-- evaluate result
				if 
					Result = 0 then put("done"); new_line;
				elsif
					Result = 1 then put("FAILED !"); new_line;
					Set_Exit_Status(Failure);
				else
					prog_position := "-----";					
-- 					put("ERROR    : Malfunction while executing test '"& test_name &"' ! Aborting ..."); new_line;
-- 					put("code     :"); put(Result); new_line; 
					raise constraint_error;
				end if;


			else 
				prog_position := "-----";
				raise constraint_error;
			end if;
		-- view test report end





		-- UUT power down begin
--		elsif action = "set" then
			--prog_position := "RU1";
			--test_name:=to_unbounded_string(Argument(2));
			
			-- check if test exists
			--if exists (compose (to_string(test_name),to_string(test_name), "vec")) then
			--	put ("running        : ");	put(test_name); new_line;
			--	put ("mode           : ");	put("production"); new_line; --put(run_mode); new_line;
				--bsm --run $run_mode $name  #launch single test/ISP
				-- launch test
			--set_directory ("/home/luno/ut");
--			gnat.directory_operations.change_dir ( "/home/luno" );
			--ada.command_line (cd /home/luno/uut);
		-- UUT power down end





		else
         	new_line;
			put ("ERROR : Action '"& action &"' not supported !"); new_line;
			put ("        For a list of available actions run command 'bsmcl' !"); new_line;
			new_line;
			prog_position := "-----";		
			raise Constraint_Error;

			
		end if;

	--end if;
   
   new_line;

	exception
		when Constraint_Error => 
			if prog_position = "ENV10" then
				put_line("ERROR ! No configuration file '" & conf_directory & conf_file_name & "' found in home directory.");

			elsif prog_position = "CRT00" then
									--new_line;
									put ("ERROR ! No action specified ! What do you want to do ?"); new_line; 
									put ("        Actions available are :");new_line;
									put ("        - create    (set up a new project)"); new_line;									
									put ("        - impcad    (import net and part lists from CAD system)"); new_line;
									put ("        - join      (merge submodule with mainmodule after CAD import)"); new_line;									
									put ("        - impbsdl   (import BSDL models)"); new_line;
									put ("        - mknets    (make boundary scan nets)"); new_line;
									put ("        - mkoptions (generate options file template)"); new_line;									
									put ("        - chkpsn    (check entries made by operator in options file)"); new_line;
									put ("        - generate  (generate a test with a certain profile)"); new_line;
									put ("        - compile   (compile a test)"); new_line;
									put ("        - load      (load a compiled test into the Boundary Scan Controller)"); new_line;
									put ("        - clear     (clear entire RAM of the Boundary Scan Controller)"); new_line;
									put ("        - dump      (view a RAM section of the Boundary Scan Controller (use for debugging only !))"); new_line;
									put ("        - run       (run a test on your UUT/target system and WAIT until test done)"); new_line;
									put ("        - start     (start a test on your UUT/target system and DO NOT WAIT until end of test)"); new_line;
									put ("        - off       (immediately stop a running test, shut down UUT power and disconnect TAP signals)"); new_line;
									put ("        - status    (query Boundary Scan Controller status)"); new_line;
									put ("        - report    (view the latest sequence execution results)"); new_line;	
									put ("        - mkvmod    (create verilog model port list from main module skeleton.txt)"); new_line;
									put ("        - help      (get examples and assistance)"); new_line;
									put ("        - firmware  (get firmware versions)"); new_line;
									put ("        Example: bsmcl help"); new_line;
								
							elsif prog_position = "PDS00" then
									put ("ERROR : No project data found in current working directory !"); new_line;
									put ("        A project directory must contain at least a file named 'proj_desc.txt' !"); new_line;									
									
							elsif prog_position = "IBL00" then
									new_line;									
									put ("ERROR ! No database specified !"); new_line; 
									--put ("        Actions available are : impcad, impbsdl, mknets, chkpsn, generate, compile, load, run"); new_line;
									put ("        Example: bsmcl impbsdl MMU.udb"); new_line;
				
							elsif prog_position = "MKN00" then
									new_line;									
									put ("ERROR ! No database specified !"); new_line; 
									--put ("        Actions available are : impcad, impbsdl, mknets, chkpsn, generate, compile, load, run"); new_line;
									put ("        Example: bsmcl mknets MMU.udb"); new_line;
				
							elsif prog_position = "JSM00" then
									new_line;									
									put ("ERROR ! No submodule specified !"); new_line; 
									--put ("        Actions available are : impcad, impbsdl, mknets, chkpsn, generate, compile, load, run"); new_line;
									put ("        Run command 'ls *.txt' to get a list of available skeleton files !"); new_line; 									 																		
									put ("        Then try example: bsmcl join skeleton_my_submodule.txt"); new_line;

				
							elsif prog_position = "JSN00" then
									new_line;
									put ("        Make sure path and name of skeleton submodule are correct !"); new_line;
									put ("        Run command 'ls *.txt' to get a list of available skeleton files !"); new_line; 									 
				
							elsif prog_position = "SMN00" then
									new_line;
									put ("ERROR ! No main module 'skeleton.txt' found. !"); new_line;
									put ("        It appears you have not imported any CAD data yet. Please import CAD data now."); new_line;
									put ("        Example: bsmcl impcad cad_format net_list [partlist]"); new_line; 									 
				
							elsif prog_position = "MKO00" then
									new_line;									
									put ("ERROR ! No database specified !"); new_line; 
									put ("        Example: bsmcl mkoptions MMU.udb"); new_line;
				
							elsif prog_position = "CPS00" then
									new_line;									
									put ("ERROR ! No database specified !"); new_line; 
									--put ("        Actions available are : impcad, impbsdl, mknets, chkpsn, generate, compile, load, run"); new_line;
									put ("        Example: bsmcl chkpsn MMU.udb"); new_line;
				
							elsif prog_position = "GEN00" then
									new_line;									
									put ("ERROR ! No database specified !"); new_line; 
									put ("        Example: bsmcl generate MMU.udb"); new_line;
				
							elsif prog_position = "OP100" then
									new_line;									
									put ("ERROR ! No options file specified !"); new_line; 
									put ("        Example: bsmcl chkpsn MMU.udb options_file.opt"); new_line;
				
							elsif prog_position = "OP200" then
									new_line;									
									put ("ERROR ! No options file specified !"); new_line; 
									put ("        Example: bsmcl mkoptions MMU.udb options_file.opt"); new_line;
				
							elsif prog_position = "OPE00" then
									new_line;									
									put ("        Make sure path and options file name are correct !"); new_line; 
									put ("        Example: bsmcl chkpsn MMU.udb options_file.opt"); new_line;
								
							elsif prog_position = "DBE00" then
									new_line;
									put ("        Make sure path and database file name are correct !"); new_line; 
				
							elsif prog_position = "ICD00" then
									new_line;									
									put ("ERROR ! No CAD format specified !"); new_line; 
									put ("        Formats available are :"); new_line;
									--put ("        - eagle4"); new_line; 
									put ("        - altium"); new_line;
									put ("        - eagle6"); new_line;									
									put ("        - orcad"); new_line;
									put ("        - zuken"); new_line;
									put ("        Example: bsmcl impcad eagle5"); new_line;
				
							elsif prog_position = "NCF00" then
									new_line;									
									put ("ERROR ! Unsupported CAD format specified !"); new_line; 
									put ("        Formats available are :"); new_line;
									--put ("        - eagle4"); new_line; 
									put ("        - altium"); new_line;
									put ("        - eagle6"); new_line;									
									put ("        - orcad"); new_line;
									put ("        - zuken"); new_line;
									put ("        Example: bsmcl impcad eagle5"); new_line;
				
							elsif prog_position = "INE00" then
									new_line;									
									put ("ERROR ! Netlist not specified !"); new_line; 
									--put ("        Formats available are : eagle4, eagle5, Conti_1"); new_line;
									put ("        Example: bsmcl impcad format cad/board.net"); new_line;

							elsif prog_position = "NLE00" then
									new_line;									
									put ("        Make sure path and netlist file name are correct !"); new_line; 
									--put ("        Formats available are : eagle4, eagle5, Conti_1"); new_line;
									put ("        Example: bsmcl impcad format cad/board.net"); new_line;

							elsif prog_position = "PLE00" then
									new_line;									
									put ("        Make sure path and partlist file name are correct !"); new_line; 
									--put ("        Formats available are : eagle4, eagle5, Conti_1"); new_line;
									put ("        Example: bsmcl impcad format cad/board.net cad/board.part"); new_line;

							elsif prog_position = "IPA00" then
									new_line;									
									put ("ERROR ! Partlist not specified !"); new_line; 
									--put ("        Formats available are : eagle4, eagle5, Conti_1"); new_line;
									put ("        Example: bsmcl impcad format cad/board.net cad/board.part"); new_line;

							elsif prog_position = "OAT00" then
									new_line;									
									put ("CANCELLED by operator !"); new_line;
									--put ("        Formats available are : eagle4, eagle5, Conti_1"); new_line;
									--put ("        Example: bsmcl impcad eagle5 cad/board.net cad/board.part"); new_line;

							elsif prog_position = "TPR00" then --or if prog_position = "TPN" then
									new_line(2);									
									--if prog_position "TPR" then put ("ERROR ! Test profile not specified !"); new_line; 
									--else put("ERROR : Specified test profile not supported !"); 
									put("ERROR : Test profile either not specified or not supported !"); new_line;
									put ("        Profiles available are : "); new_line;
									put ("        - infrastructure"); new_line;
									put ("        - interconnect"); new_line;									
									put ("        - memconnect"); new_line;									
									put ("        - clock"); new_line;
									put ("        - toggle"); new_line;									
									put ("        Example: bsmcl generate MMU.udb infrastructure"); new_line;
				
							elsif prog_position = "TNA00" then
									new_line;									
									put ("ERROR ! Test name not specified !"); new_line; 
									put ("        Example: bsmcl generate MMU.udb profile my_test_name"); new_line;

							elsif prog_position = "TDV00" then
									new_line;									
									put ("ERROR ! Target device not specified !"); new_line; 
									put ("        Example: bsmcl generate MMU.udb memconnect my_test_name IC202"); new_line;

							--elsif prog_position = "TOD" then
							--		new_line;									
							--		put ("ERROR ! Target device not specified !"); new_line; 
							--		put ("        Example: bsmcl generate MMU.udb toggle my_test_name IC3"); new_line;

							elsif prog_position = "DVM00" then
									new_line;									
									put ("ERROR ! Device model not specified !"); new_line; 
									put ("        Example: bsmcl generate MMU.udb memconnect my_test_name RAM_IC202 models/U62256.txt"); new_line;

							elsif prog_position = "DMN00" then
									new_line;									
									put ("        Make sure path and model file name are correct !"); new_line; 
									put ("        Example: bsmcl generate MMU.udb memconnect my_test_name RAM_IC202 models/U62256.txt"); new_line;

							elsif prog_position = "DPC00" then
									new_line;									
									put ("ERROR ! Device package not specified !"); new_line; 
									put ("        Example: bsmcl generate MMU.udb memconnect my_test_name RAM_IC202 models/U62256.txt NDIP28"); new_line;

							elsif prog_position = "TPI00" then
									new_line;									
									put ("ERROR ! Receiver pin not specified !"); new_line; 
									put ("        Example: bsmcl generate MMU.udb clock my_test_name IC7 56"); new_line;

							elsif prog_position = "TON00" then
									new_line;									
									put ("ERROR ! Target net not specified !"); new_line; 
									put ("        Example: bsmcl generate MMU.udb toggle my_test_name SIO_CLK"); new_line;

							elsif prog_position = "RYC00" then
									new_line;									
									put ("ERROR ! Max retry count not specified !"); new_line; 
									put ("        Example: bsmcl generate MMU.udb clock my_test_name IC7 56 10"); new_line;

							elsif prog_position = "RDY00" then
									new_line;									
									put ("ERROR ! Retry delay (unit is sec) not specified !"); new_line; 
									put ("        Example: bsmcl generate MMU.udb clock my_test_name IC7 56 1 "); new_line;

							elsif prog_position = "TCT00" then
									new_line;									
									put ("ERROR ! Cycle count not specified !"); new_line; 
									put ("        Example: bsmcl generate MMU.udb toggle my_test_name SIO_CLK 10"); new_line;

							elsif prog_position = "TLT00" then
									new_line;									
									put ("ERROR ! Low time (unit is sec) not specified !"); new_line; 
									put ("        Example: bsmcl generate MMU.udb toggle my_test_name SIO_CLK 10 2"); new_line;

							elsif prog_position = "THT00" then
									new_line;									
									put ("ERROR ! High time (unit is sec) not specified !"); new_line; 
									put ("        Example: bsmcl generate MMU.udb toggle my_test_name SIO_CLK 10 2 0.5"); new_line;

							elsif prog_position = "PJN00" then
									new_line;									
									put ("ERROR ! Project name not specified !"); new_line; 
									put ("        Example: bsmcl create new_project_name"); new_line;

							elsif prog_position = "CMP00" then
									new_line;									
									put ("ERROR ! No database specified !"); new_line; 
									put ("        Example: bsmcl compile MMU.udb"); new_line;

							elsif prog_position = "CTN00" then
									new_line;									
									put ("ERROR ! Test name not specified !"); new_line; 
									put ("        Example: bsmcl compile MMU.udb my_test_name"); new_line;


							elsif prog_position = "CNE00" then
									new_line;									
									put ("ERROR : Test '"& test_name &"' has not been generated yet !"); new_line;
									put ("        Please generate test, then try again."); new_line;

							elsif prog_position = "LD100" then
									new_line;									
									put ("ERROR : Test name not specified !"); new_line;
									put ("        Example: bsmcl load my_test_name"); new_line;

							elsif prog_position = "LD200" or prog_position = "RU2" then
									new_line;									
									put ("ERROR : Test '"& test_name &"' either does not exist or has not been compiled yet !"); new_line;
									put ("        Please generate/compile test, then try again."); new_line;

							elsif prog_position = "RU100" then
									new_line;									
									put ("ERROR : Test name not specified !"); new_line;
									put ("        Example: bsmcl run my_test_name"); new_line;

							elsif prog_position = "RU400" then
									new_line;									
									put ("ERROR : Step mode not supported or invalid !"); new_line;
									put ("        Example: bsmcl run my_test_name [step_mode]"); new_line;
									put ("        Supported step modes are: ");
									for p in 0..m1_internal.step_mode_count
									loop
										put(m1_internal.step_mode_type'image(m1_internal.step_mode_type'val(p)));
										if p < m1_internal.step_mode_count then put(" , "); end if;
									end loop;
									new_line;


							elsif prog_position = "LD300" or prog_position = "RU3" then
									new_line;									
									put("Measures : - Check cable connection between PC and BSC !"); new_line;
									put("           - Make sure BSC is powered on (GREEN LED flashes) !"); new_line;					
									put("           - Push YELLOW reset button on BSC, then try again !"); new_line;															

							elsif prog_position = "ACV00" then
									new_line;
									put ("ERROR ! Too little arguments specified !"); new_line;
									put ("        Example: mkvmod skeleton.txt your_verilog_module (without .v extension)"); new_line;  

							end if;
									new_line;
									put ("PROGRAM ABORTED !"); new_line; 
									put_line(prog_position);
									new_line;
									Set_Exit_Status(Failure);		

		
   --Spawn
   --(  Program_Name           => "/bin/ls",
   --   Args                   => Arguments,
   --   Output_File_Descriptor => Standout,
   --   Return_Code            => Result
   --);
   --for Index in Arguments'Range loop
   --   Free (Arguments (Index)); -- Free the argument list
   --end loop;
		when others => 
				new_line;
				put ("PROGRAM ABORTED !"); new_line; 
				put_line(prog_position);
				new_line;
				Set_Exit_Status(Failure);		

end bsmcl;