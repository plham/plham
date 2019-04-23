package plham;
import x10.util.List;
import x10.util.ArrayList;
import x10.util.StringUtil;
import plham.util.JSON;
import plham.main.SequentialRunner;
import plham.main.Simulator;

/**
 * The base class for user-defined <q>main</q> classes.
 * See the <code>samples</code> to know how to extend this class.
 */
public class Main extends Simulator {

	public static def main(args:Rail[String]) {
		val sim = new Main();
		new SequentialRunner[Main](sim).run(args);
	}
	
	//** Here are a list of core fields and methods from Simulator. **//

//	public var GLOBAL:Map[String,Any]; // JSON key (top-level) -> JSON.Value

//	public var CONFIG:JSON.Value; // The value of JSON.parse(args(0))

	/**
	 * Called at the beginning of the simulation (before the first session).
	 */
	public def beginSimulation() {}

	/**
	 * Called at the end of the simulation (after the last session).
	 */
	public def endSimulation() {}

	/**
	 * Called at the beginning of every session.
	 * @param sessionName
	 */
	public def beginSession(sessionName:String) {}

	/**
	 * Called at the end of every session.
	 * @param sessionName
	 */
	public def endSession(sessionName:String) {}

	public def endprint(sessionName:String,iterationSteps:Long) {

	}

	/**
	 * Override this to configure the standard outputs of the simulation.
	 * Called in the middle of every step of sessions.
	 * @param sessionName
	 */
	public def print(sessionName:String) {
		val markets = getMarketsByName("markets") as List[Market];
		for (market in markets) {
			val t = market.getTime();
			Console.OUT.println(StringUtil.formatArray([
				sessionName,
				t, 
				market.id,
				market.name,
				market.getPrice(t),
				market.getFundamentalPrice(t),
				"", ""], " ", "", Int.MAX_VALUE));
		}
	}
}
