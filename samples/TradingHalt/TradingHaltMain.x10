package samples.TradingHalt;
import x10.util.ArrayList;
import x10.util.List;
import x10.util.StringUtil;
import plham.Agent;
import plham.Event;
import plham.Market;
import plham.event.FundamentalPriceShock;
import plham.event.TradingHaltRule;
import plham.util.JSON;
import plham.util.JSONRandom;
import samples.CI2002.CI2002Main;
import plham.main.SequentialRunner;

public class TradingHaltMain extends CI2002Main {

	public static def main(args:Rail[String]) {
		new SequentialRunner(new TradingHaltMain()).run(args);
	}

	public def print(sessionName:String) {
		val markets = getMarketsByName("markets");
		val agents = getAgentsByName("agents");
		for (market in markets) {
			val t = market.getTime();
			Console.OUT.println(StringUtil.formatArray([
				sessionName,
				t, 
				market.id,
				market.name,
				market.getPrice(t),
				market.getFundamentalPrice(t),
				market.isRunning(),
				"", ""], " ", "", Int.MAX_VALUE));
		}
	}

	public def createEvents(json:JSON.Value):List[Event] {
		val random = new JSONRandom(getRandom());
		val events = new ArrayList[Event]();
		if (!json("enabled").toBoolean()) {
			return events;
		}
		if (json("class").equals("FundamentalPriceShock")) {
			val shock = new FundamentalPriceShock();
			setupFundamentalPriceShock(shock, json, random);
			events.add(shock);

			Console.OUT.println("# " + json("class").toString() + " : " + JSON.dump(json));
		}
		if (json("class").equals("TradingHaltRule")) {
			val rule = new TradingHaltRule();
			setupTradingHaltRule(rule, json, random);
			events.add(rule);

			Console.OUT.println("# " + json("class").toString() + " : " + JSON.dump(json));
		}
		return events;
	}

	public def setupFundamentalPriceShock(shock:FundamentalPriceShock, json:JSON.Value, random:JSONRandom) {
		val market = getMarketByName(json("target"));
		shock.marketId = market.id;
		shock.triggerTime = json("triggerTime").toLong();
		shock.shockTimeLength = FundamentalPriceShock.NO_TIME_LENGTH;
		shock.priceChangeRate = json("priceChangeRate").toDouble();
		market.addBeforeSimulationStepEvent(shock);
	}

	public def setupTradingHaltRule(rule:TradingHaltRule, json:JSON.Value, random:JSONRandom) {
		val market = getMarketByName(json("referenceMarket"));
		rule.referenceMarketId = market.id;
		rule.referencePrice = market.getPrice();
		rule.triggerChangeRate = json("triggerChangeRate").toDouble();
		rule.haltingTimeLength = json("haltingTimeLength").toLong();
		val targetMarkets = getMarketsByName(json("targetMarkets"));
		rule.addTargetMarkets(targetMarkets);
		market.addAfterOrderHandlingEvent(rule);
	}
}
