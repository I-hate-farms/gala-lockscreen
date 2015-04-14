
public enum PresenceStatus
{
	AVAILABLE,
	INVISIBLE,
	BUSY,
	IDLE
}

[DBus (name = "org.gnome.SessionManager.Presence")]
public interface GnomePresence : Object
{
	public abstract void set_status (uint32 status) throws IOError;
	public signal void status_changed (uint32 status);
}

