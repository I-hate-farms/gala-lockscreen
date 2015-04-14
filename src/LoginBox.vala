using Clutter;

namespace Gala
{
	public class LoginBox : Actor
	{
		public signal void try_authenticate (string password);

		public double scale_both {
			get {
				return scale_x;
			}
			set {
				print("SET TO %f\n", value);
				set_scale (value, value);
			}
		}

		Text password;
		Texture avatar;
		Text user_name;

		const int PADDING = 24;
		const int AVATAR_SIZE = 96;

		public LoginBox ()
		{
			width = 400;
			height = 300;

			var layout = new BoxLayout ();
			layout_manager = layout;
			layout.orientation = Clutter.Orientation.VERTICAL;
			layout.spacing = 12;

			var canvas = new Canvas ();
			canvas.draw.connect (draw_background);
			canvas.set_size ((int)width, (int)height);
			content = canvas;

			password = new Text ();
			password.font_name = new GLib.Settings ("org.gnome.desktop.interface").get_string ("font-name");
			password.password_char = '*';
			password.editable = true;
			password.cursor_visible = true;
			password.key_press_event.connect ((e) => {
				if (e.keyval == Clutter.Key.Return && password.text != "") {
					var pw = password.text;
					password.text = "";
					try_authenticate (pw);
					return true;
				}
				return false;
			});

			user_name = new Text.with_text ("Droid Sans Bold 16",
					Environment.get_real_name ());
			user_name.color = {50, 50, 50, 255};

			string? avatar_file = null;
			var settings_file = new KeyFile ();
			try {
				settings_file.load_from_file ("/var/lib/AccountsService/users/" + Environment.get_user_name (), 0);
				avatar_file = settings_file.get_string ("User", "Icon");
			} catch (Error e) {
				var home_file = Environment.get_home_dir () + "/.face";
				if (File.new_for_path (home_file).query_exists ())
					avatar_file = home_file;
			}

			if (avatar_file != null) {
				try {
					avatar = new Texture.from_file (avatar_file);
					avatar.set_size (AVATAR_SIZE, AVATAR_SIZE);
					avatar.margin_top = 48;
				} catch (Error e) { warning (e.message); }
			} else {
				avatar = new GtkClutter.Texture ();
				avatar.set_size (AVATAR_SIZE, AVATAR_SIZE);
				avatar.margin_top = 48;

				try {
					var pixbuf = Gtk.IconTheme.get_default ().load_icon ("avatar-default",
							AVATAR_SIZE, 0);
					((GtkClutter.Texture) avatar).set_from_pixbuf (pixbuf);
				} catch (Error e) {
					background_color = { 150, 150, 150, 255 };
					warning (e.message);
					// we have a valid, but empty actor now. That suffices.
				}
			}

			if (avatar != null)
				add_child (avatar);

			add_child (user_name);
			add_child (password);
		}

		bool draw_background (Cairo.Context cr)
		{
			cr.set_operator (Cairo.Operator.CLEAR);
			cr.paint ();
			cr.set_operator (Cairo.Operator.OVER);

			var buffer = new Granite.Drawing.BufferSurface ((int)width, (int)height);

			var width = (int)width - PADDING * 2;
			var height = (int)height - PADDING * 2;

			Granite.Drawing.Utilities.cairo_rounded_rectangle (buffer.context, PADDING, PADDING, width, height, 5);
			buffer.context.set_source_rgba (0, 0, 0, 1);
			buffer.context.fill ();
			buffer.exponential_blur (12);

			cr.set_source_surface (buffer.surface, 0, 0);
			cr.paint ();

			Granite.Drawing.Utilities.cairo_rounded_rectangle (cr, PADDING, PADDING, width, height, 5);
			cr.set_source_rgb (1, 1, 1);
			cr.fill ();

			return false;
		}

		public void focus ()
		{
			password.grab_key_focus ();
		}

		public void play_auth_failed_animation ()
		{
			var anim = new Clutter.KeyframeTransition ("scale-both");
			anim.progress_mode = Clutter.AnimationMode.EASE_IN_BOUNCE;
			anim.set_from_value (0.4);
			anim.set_to_value (1.0);
			anim.set_key_frames ({ 0.5 });
			anim.set_values ({ 0.9 });
			// anim.set_modes ({ Clutter.AnimationMode.EASE_OUT_BOUNCE });
			anim.duration = 600;
			anim.remove_on_complete = true;

			add_transition ("shake", anim);
		}

		public void animate_out ()
		{
			save_easing_state ();
			set_easing_mode (Clutter.AnimationMode.EASE_OUT_CUBIC);
			set_easing_duration (400);
			opacity = 0;
			set_scale (0.8, 0.8);
			restore_easing_state ();

			var transition = get_transition ("opacity");
			if (transition != null)
				transition.completed.connect (() => {
					visible = false;
				});
			else
				visible = false;
		}

		public void animate_in (bool do_animate, float x, float y)
		{
			if (do_animate) {
				opacity = 0;
				set_scale (0.8, 0.8);
				visible = true;
				set_position (x, y);

				save_easing_state ();
				set_easing_mode (Clutter.AnimationMode.EASE_OUT_CUBIC);
				set_easing_duration (400);
			}

			set_scale (1, 1);
			opacity = 255;

			if (do_animate)
				restore_easing_state ();
		}
	}
}
