
namespace Gala.Plugins.Lockscreen
{
	public class Main : Gala.Plugin
	{
		GtkClutter.Texture watermark;

		WindowManager wm;
		LoginBox login_box;
		DBus dbus;
		ModalProxy modal_proxy;

		bool listener_connected = false;

		public override void initialize (Gala.WindowManager wm)
		{
			this.wm = wm;
			dbus = new DBus ();

			login_box = new LoginBox ();
			login_box.reactive = true;
			login_box.visible = false;
			login_box.anchor_gravity = Clutter.Gravity.CENTER;

			watermark = new GtkClutter.Texture ();
			watermark.visible = false;
			try {
				watermark.set_from_pixbuf (
					Gtk.IconTheme.get_default ().lookup_icon ("changes-prevent-symbolic", 650,
						Gtk.IconLookupFlags.FORCE_SIZE).
					load_symbolic ({0.1, 0.1, 0.1, 0.6}));
			} catch (Error e) {
				warning (e.message);
			}

			wm.stage.add_child (watermark);
			wm.stage.add_child (login_box);

			dbus.toggle_lock.connect (toggle_lock);
			dbus.auth_failed.connect (login_box.play_auth_failed_animation);
			dbus.show_loginbox_after_suspend.connect (show_loginbox);

			login_box.try_authenticate.connect (dbus.try_authenticate);
		}

		public override void destroy ()
		{
			// TODO
		}

		void toggle_lock (bool active, AnimationType animation_type)
		{
			// unlock
			if (!active) {
				wm.pop_modal (modal_proxy);

				wm.ui_group.save_easing_state ();
				wm.ui_group.set_easing_mode (Clutter.AnimationMode.EASE_OUT_CUBIC);
				wm.ui_group.set_easing_duration (400);
				wm.ui_group.y = 0.0f;
				wm.ui_group.opacity = 255;
				wm.ui_group.restore_easing_state ();

				login_box.animate_out ();

				// TODO delay
				watermark.visible = false;

				// stage.set_child_below_sibling (group, window_group);
				// stage.set_child_below_sibling (watermark, group);

				toggle_listener (false);

				return;
			}

			// lock
			modal_proxy = wm.push_modal ();

			if (animation_type == AnimationType.INTERRUPTABLE) {
				toggle_listener (true);
			}

			if (animation_type == AnimationType.IMMEDIATE) {
				wm.ui_group.y = -wm.ui_group.height;
				wm.ui_group.opacity = 0;
			} else {
				wm.ui_group.save_easing_state ();
				wm.ui_group.set_easing_mode (Clutter.AnimationMode.LINEAR);
				wm.ui_group.set_easing_duration (animation_type == AnimationType.ANIMATED ?
						250 : 3000);
				wm.ui_group.y = -wm.ui_group.height;
				wm.ui_group.opacity = 0;
				wm.ui_group.restore_easing_state ();
			}

			Clutter.Callback transition_finished = () => {
				toggle_listener (false);

				int screen_width, screen_height;
				wm.get_screen ().get_size (out screen_width, out screen_height);

				wm.stage.set_child_above_sibling (login_box, null);
				wm.stage.set_child_below_sibling (watermark, login_box);

				if (animation_type != AnimationType.IMMEDIATE) {
					show_loginbox ();
				}

				watermark.set_position (screen_width / 2 - watermark.width / 2,
					                    screen_height / 2 - watermark.height / 2 - 120);
				watermark.opacity = 0;
				watermark.visible = true;

				watermark.save_easing_state ();
				watermark.set_easing_duration (animation_type == AnimationType.IMMEDIATE ?
						0 : 4000);
				watermark.opacity = 255;
				watermark.restore_easing_state ();
			};

			var transition = wm.ui_group.get_transition ("y");
			if (transition != null)
				wm.ui_group.get_transition ("y").completed.connect (() => {
					transition_finished (wm.ui_group);
				});
			else
				transition_finished (wm.ui_group);
		}

		void show_loginbox ()
		{
			int screen_width, screen_height;
			wm.get_screen ().get_size (out screen_width, out screen_height);

			login_box.animate_in (true, screen_width / 2, screen_height / 2);
			login_box.focus ();
		}

		void toggle_listener (bool active)
		{
			if (active && !listener_connected) {
				listener_connected = true;
				wm.stage.captured_event.connect (listen_for_events);
			} else if (!active && listener_connected) {
				listener_connected = false;
				wm.stage.captured_event.disconnect (listen_for_events);
			}
		}

		bool listen_for_events (Clutter.Event event)
		{
			switch (event.get_type ()) {
				case Clutter.EventType.BUTTON_PRESS:
				case Clutter.EventType.KEY_PRESS:
				case Clutter.EventType.MOTION:
				case Clutter.EventType.TOUCH_BEGIN:
				case Clutter.EventType.TOUCH_UPDATE:
					abort ();
					break;
				default:
					break;
			}

			return false;
		}

		void abort ()
		{
			toggle_lock (false, AnimationType.ANIMATED);
		}
	}
}

public Gala.PluginInfo register_plugin ()
{
	return Gala.PluginInfo () {
		name = "Lockscreen",
		author = "Gala Developers",
		plugin_type = typeof (Gala.Plugins.Lockscreen.Main),
		provides = Gala.PluginFunction.ADDITION,
		load_priority = Gala.LoadPriority.IMMEDIATE
	};
}

