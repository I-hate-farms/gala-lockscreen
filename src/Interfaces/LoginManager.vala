
[DBus (name = "org.freedesktop.login1.Manager")]
public interface LoginManagerSystemd : Object
{
	public signal void prepare_for_sleep (bool about_to_suspend);

	public abstract async ObjectPath get_session (string id) throws IOError;
	public abstract async UnixInputStream inhibit (string what, string who, string why, string mode) throws IOError;
}

[DBus (name = "org.freedesktop.login1.Session")]
public interface SessionProxy : Object
{
	public signal void @lock ();
	public signal void unlock ();
}

public class LoginManager : Object
{
	public signal void prepare_for_sleep (bool about_to_suspend);

	SessionProxy? session_proxy;
	LoginManagerSystemd? login_manager;
	UnixInputStream? inhibitor = null;

	public LoginManager ()
	{
	}

	public async SessionProxy? get_current_session_proxy ()
	{
		if (session_proxy != null)
			return session_proxy;

		yield init_manager ();

		var id = Environment.get_variable ("XDG_SESSION_ID");
		try {
			var path = yield login_manager.get_session (id);

			session_proxy = yield Bus.get_proxy (BusType.SYSTEM,
					"org.freedesktop.login1", path);
		} catch (Error e) {
			warning (e.message);
			return null;
		}

		return session_proxy;
	}

	public async void inhibit (string reason)
	{
		yield init_manager ();
		inhibitor = yield login_manager.inhibit ("sleep", "Gala", reason, "delay");
	}

	public async void uninhibit ()
	{
		yield inhibitor.close_async ();
		inhibitor = null;
	}

	async void init_manager ()
	{
		if (login_manager != null)
			return;

		login_manager = yield Bus.get_proxy (BusType.SYSTEM, "org.freedesktop.login1",
				"/org/freedesktop/login1");
		login_manager.prepare_for_sleep.connect ((p) => prepare_for_sleep (p));
	}
}
