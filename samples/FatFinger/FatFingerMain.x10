package samples.CI2002;
import x10.util.ArrayList;
import x10.util.List;
import x10.util.StringUtil;
import plham.Agent;
import plham.Market;
import plham.Event;
import plham.agent.FCNAgent;
import plham.event.OrderMistakeShock;
import plham.util.JSON;
import plham.util.JSONRandom;
import plham.main.SequentialRunner;
import samples.CI2002.CI2002Main;

public class FatFingerMain extends CI2002Main {

	public static def main(args:Rail[String]) {
		new SequentialRunner(new FatFingerMain()).run(args);
	}

	public def print(sessionName:String) {
		super.print(sessionName);
		val markets = getMarketsByName("markets");
		for (market in markets) {
			market.getBuyOrderBook().dump();  /* WARNING: This dumps all orders in the orderbook!! */
			market.getSellOrderBook().dump(); /* WARNING: This dumps all orders in the orderbook!! */
		}
	}

	public def createEvents(json:JSON.Value):List[Event] {
		val random = new JSONRandom(getRandom());
		val events = new ArrayList[Event]();
		if (!json("enabled").toBoolean()) {
			return events;
		}
		if (json("class").equals("OrderMistakeShock")) {
			val shock = new OrderMistakeShock();
			setupOrderMistakeShock(shock, json, random);
			events.add(shock);

			Console.OUT.println("# " + json("class").toString() + " : " + JSON.dump(json));
		}
		return events;
	}

	public def setupOrderMistakeShock(shock:OrderMistakeShock, json:JSON.Value, random:JSONRandom) {
		val market = getMarketByName(json("target"));
		val agent = getAgentsByName(json("agent"))(0); // Use the first one.
		val t = market.getTime();
		shock.marketId = market.id;
		shock.agentId = agent.id;
		shock.triggerTime = t + json("triggerTime").toLong();
		shock.priceChangeRate = json("priceChangeRate").toDouble();
		shock.orderVolume = json("orderVolume").toLong();
		shock.orderTimeLength = json("orderTimeLength").toLong();
		market.addBeforeSimulationStepEvent(shock);
	}
}
