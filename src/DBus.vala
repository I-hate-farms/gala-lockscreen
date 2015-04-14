
[CCode (cname = "pam_auth")]
public extern bool pam_auth_user (string user, string password);

[DBus (name = "org.freedesktop.DisplayManager")]
public interface Seat : Object
{
	public abstract void switch_to_greeter () throws Error;
}

namespace Gala.Plugins.Lockscreen
{
	public enum AnimationType
	{
		INTERRUPTABLE,
		ANIMATED,
		IMMEDIATE
	}

	[DBus (name = "org.gnome.ScreenSaver")]
	public class DBus : Object
	{
		public signal void toggle_lock (bool locked, AnimationType type);
		public signal void auth_failed ();
		public signal void show_loginbox_after_suspend ();

		Seat? seat;
		GnomePresence presence;
		LoginManager login_manager;
		Meta.IdleMonitor idle_monitor;
		uint lock_timeout = 0;
		uint idle_watch_id = 0;
		int64 activation_time;

		bool _active = false;

		public DBus ()
		{
			Bus.own_name (BusType.SESSION, 
				"org.gnome.ScreenSaver",
				BusNameOwnerFlags.NONE,
				(connection) => {
					try {
						connection.register_object ("/org/gnome/ScreenSaver", this);
					} catch (Error e) { warning (e.message); }
				},
				() => {},
				(connection, name) => { warning ("Could not aquire bus %s", name); });

			try {
				seat = Bus.get_proxy_sync (BusType.SYSTEM, "org.freedesktop.DisplayManager",
					Environment.get_variable ("XDG_SEAT_PATH"));

				presence = Bus.get_proxy_sync (BusType.SESSION, "org.gnome.SessionManager.Presence",
						"/org/gnome/SessionManager/Presence");

			} catch (Error e) {
				warning ("Failed to initialize DBus helpers for lockscreen: %s", e.message);
				return;
			}

			login_manager = new LoginManager ();
			login_manager.get_current_session_proxy.begin ((obj, res) => {
				var proxy = login_manager.get_current_session_proxy.end (res);

				if (proxy == null)
					return;

				proxy.@lock.connect (() => {
					set_active (true, AnimationType.ANIMATED);
				});

				proxy.unlock.connect (() => {
					set_active (false, AnimationType.ANIMATED);
				});
			});
			login_manager.prepare_for_sleep.connect ((about_to_suspend) => {
				print ("PREPARE FOR SLEEP!!! %i\n", (int) about_to_suspend);
				if (about_to_suspend) {
					if (!LockSettings.get_default ().lock_enabled) {
						uninhibit_suspend ();
						return;
					}
					set_active (true, AnimationType.IMMEDIATE);
				} else {
					inhibit_suspend ();
					wake_up_screen ();
					show_loginbox_after_suspend ();
				}
			});

			idle_monitor = Meta.IdleMonitor.get_core ();

			presence.status_changed.connect ((status) => {
				var settings = LockSettings.get_default ();

				if (status != PresenceStatus.IDLE || settings.lock_delay == 0)
					return;

				if (activation_time == 0)
					activation_time = GLib.get_monotonic_time ();

				if (!settings.lock_enabled)
					return;

				if (lock_timeout != 0)
					Source.remove (lock_timeout);

				lock_timeout = Timeout.add (settings.lock_delay * 1000, () => {
					lock_timeout = 0;
					set_active (true, AnimationType.INTERRUPTABLE);

					return GLib.Source.REMOVE;
				});

				if (idle_watch_id == 0)
					idle_watch_id = idle_monitor.add_user_active_watch (() => {
						idle_monitor.remove_watch (idle_watch_id);
						idle_watch_id = 0;

						if (lock_timeout != 0)
							Source.remove (lock_timeout);
						lock_timeout = 0;
					});
			});
		}

		/*public bool get_active ()
		{
			return _active;
		}*/

		void inhibit_suspend ()
		{
			login_manager.inhibit.begin ("Gala needs to lock the screen");
		}

		void uninhibit_suspend ()
		{
			login_manager.uninhibit.begin ();
		}

		void wake_up_screen ()
		{
		}

		public uint32 get_active_time ()
		{
			return (uint32) activation_time;
		}

		public void @lock ()
		{
			set_active (true, AnimationType.ANIMATED);
		}

		public void set_active (bool active, AnimationType type)
		{
			print ("SET ACTIVE %i (%i)\n", (int) active, (int) _active);

			if (_active == active)
				return;

			_active = active;
			activation_time = active ? GLib.get_monotonic_time () : 0;

			toggle_lock (active, type);
		}

		public void show_message (string summary, string body, string icon)
		{
			warning ("show_message not implemented yet: %s, %s, %s\n",
					summary, body, icon);
		}

		public void try_authenticate (string password)
		{
			if (pam_auth_user (Environment.get_user_name (), password)) {
				set_active (false, AnimationType.ANIMATED);
			} else {
				auth_failed ();
			}
		}
	}
}

