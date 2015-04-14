
public class LockSettings : Granite.Services.Settings
{
	public static unowned LockSettings get_default ()
	{
		if (instance == null)
			instance = new LockSettings ();
		return instance;
	}

	static LockSettings? instance = null;

	public bool lock_enabled { get; set; }
	public int lock_delay { get; set; }

	LockSettings ()
	{
		base ("org.gnome.desktop.screensaver");
	}
}
