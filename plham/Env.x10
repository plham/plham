package plham;
import x10.util.ArrayList;
import x10.util.List;

/**
 * For system use only.
 */
public class Env {

	public static DEBUG = 0;

	public static def getenvOrElse(name:String, orElse:String):String {
		val value = System.getenv(name);
		if (value == null) {
			return orElse;
		}
		return value;
	}

	public var agents:List[Agent]; // MEMO TT it has to be val???
	public var numAgents:Long; // TODO tmporal, distCol should holds the total num.
	public var markets:List[Market];

	public var normalAgents:List[Agent];
	public var hifreqAgents:List[Agent];
    
	public def this() {
		//TODO
				this.agents = new ArrayList[Agent]();
	}
}

// Local Variables:
// indent-tabs-mode: t
// tab-width: 4
// End:
