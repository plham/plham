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

//	public static def main(args:Rail[String]) {
//		new SequentialRunner[Main](new Main()).run(args);
//	}
	
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

	/**
	 * Override this to configure the standard outputs of the simulation.
	 * Called in the middle of every step of sessions.
	 * @param sessionName
	 */
	public def print(sessionName:String) {
		val markets = GLOBAL("markets") as List[Market];
		val agents = GLOBAL("agents") as List[Agent];
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

	/**
	 * Override this to create agents.
	 * @param json  a JSON object, or properties of agents.
	 * @return a list of agents.
	 */
	public def createAgents(json:JSON.Value):List[Agent] {
		return new ArrayList[Agent]();
	}

	/**
	 * Override this to create markets.
	 * @param json  a JSON object, or properties of markets.
	 * @return a list of markets.
	 */
	public def createMarkets(json:JSON.Value):List[Market] {
		return new ArrayList[Market]();
	}

	/**
	 * Override this to create events.
	 * @param json  a JSON object, or properties of events.
	 * @return a list of events.
	 */
	public def createEvents(json:JSON.Value):List[Event] {
		return new ArrayList[Event]();
	}

	//** Here are a list of utility methods to access to GLOBAL. */

	public def getMarketsByName(json:JSON.Value) = getItemsByName[Market](json);

	public def getMarketByName(json:JSON.Value) = getItemByName[Market](json);

	public def getMarketsByName(names:List[String]) = getItemsByName[Market]((i:Long) => names(i), names.size());

	public def getMarketsByName(name:String) = getItemsByName[Market](name);

	public def getMarketByName(name:String) = getItemByName[Market](name);

	public def getAgentsByName(json:JSON.Value) = getItemsByName[Agent](json);

	public def getAgentByName(json:JSON.Value) = getItemByName[Agent](json);

	public def getAgentsByName(names:List[String]) = getItemsByName[Agent]((i:Long) => names(i), names.size());

	public def getAgentsByName(name:String) = getItemsByName[Agent](name);

	public def getAgentByName(name:String) = getItemByName[Agent](name);

	public def getEventsByName(json:JSON.Value) = getItemsByName[Event](json);

	public def getEventByName(json:JSON.Value) = getItemByName[Event](json);

	public def getEventsByName(names:List[String]) = getItemsByName[Event]((i:Long) => names(i), names.size());

	public def getEventsByName(name:String) = getItemsByName[Event](name);

	public def getEventByName(name:String) = getItemByName[Event](name);
}
