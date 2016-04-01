package samples.PriceLimit;
import x10.util.ArrayList;
import x10.util.List;
import x10.util.StringUtil;
import plham.Agent;
import plham.Event;
import plham.Market;
import plham.event.PriceLimitRule;
import plham.util.JSON;
import plham.util.JSONRandom;
import samples.CI2002.CI2002Main;
import plham.main.SequentialRunner;

public class PriceLimitMain extends CI2002Main {

	public static def main(args:Rail[String]) {
		new SequentialRunner(new PriceLimitMain()).run(args);
	}

	public def createAgents(json:JSON.Value):List[Agent] {
		val random = new JSONRandom(getRandom());
		val agents = super.createAgents(json); // Use FCNAgent defined in CI2002Main.
		if (json("class").equals("PriceLimitFCNAgent")) {
			val numAgents = json("numAgents").toLong();
			for (i in 0..(numAgents - 1)) {
				val agent = new PriceLimitFCNAgent();
				setupPriceLimitFCNAgent(agent, json, random);
				agents.add(agent);
			}
			Console.OUT.println("# " + json("class").toString() + " : " + JSON.dump(json));
		}
		return agents;
	}

	public def createEvents(json:JSON.Value):List[Event] {
		val random = new JSONRandom(getRandom());
		val events = new ArrayList[Event]();
		if (!json("enabled").toBoolean()) {
			return events;
		}
		if (json("class").equals("PriceLimitRule")) {
			val rule = new PriceLimitRule();
			setupPriceLimitRule(rule, json, random);
			events.add(rule);

			Console.OUT.println("# " + json("class").toString() + " : " + JSON.dump(json));
		}
		return events;
	}

	public def setupPriceLimitFCNAgent(agent:PriceLimitFCNAgent, json:JSON.Value, random:JSONRandom) {
		setupFCNAgent(agent, json, random);
		agent.priceLimit = createEvents(CONFIG(json("priceLimit")))(0) as PriceLimitRule;
	}

	public def setupPriceLimitRule(rule:PriceLimitRule, json:JSON.Value, random:JSONRandom) {
		val referenceMarket = getMarketByName(json("referenceMarket"));
		rule.referenceMarketId = referenceMarket.id;
		rule.referencePrice = referenceMarket.getPrice();
		rule.triggerChangeRate = json("triggerChangeRate").toDouble();
		referenceMarket.addBeforeOrderHandlingEvent(rule);
	}
}
