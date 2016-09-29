with gtk.widget;  				use gtk.widget;
with gtk.button;  				use gtk.button;
with gtk.image;					use gtk.image;
with gtk.file_chooser_button;	use gtk.file_chooser_button;
with glib.object;

with gdk.event;

package bsmgui_cb is

	button_start_stop_test		: gtk_button;
	button_start_stop_script	: gtk_button;
	button_abort_shutdown		: gtk_button;

	chooser_set_uut		: gtk_file_chooser_button;
	chooser_set_script	: gtk_file_chooser_button;
	chooser_set_test	: gtk_file_chooser_button;

	img_status			: gtk.image.gtk_image;

	procedure terminate_main (self : access gtk_widget_record'class);
	procedure set_project (self : access gtk_file_chooser_button_record'class);
	procedure set_script (self : access gtk_file_chooser_button_record'class);
	procedure set_test (self : access gtk_file_chooser_button_record'class);
	procedure start_stop_test (self : access gtk_button_record'class);
	procedure start_stop_script (self : access gtk_button_record'class);
	procedure abort_shutdown (self : access gtk_button_record'class);

end bsmgui_cb;
