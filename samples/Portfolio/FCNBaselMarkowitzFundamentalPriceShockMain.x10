package samples.Portfolio;
import x10.util.ArrayList;
import x10.util.List;
import x10.util.Random;
import x10.util.StringUtil;
import plham.Agent;
import plham.Env;
import plham.Fundamentals;
import plham.event.FundamentalPriceShock;
import plham.Market;
import plham.Order;
import plham.Event;
import samples.Portfolio.FCNMarkowitzPortfolioAgent;
import samples.Portfolio.FCNBaselMarkowitzPortfolioAgent;
import samples.Portfolio.FCNBaselMarkowitzCI2002Main;
import cassia.util.JSON;
import x10.util.Map;
import x10.util.HashMap;
import plham.main.SequentialRunner;
import plham.Main;
import plham.util.JSONRandom;

public class FCNBaselMarkowitzFundamentalPriceShockMain extends FCNBaselMarkowitzCI2002Main {

	public static def main(args:Rail[String]) {
		val sim = new FCNBaselMarkowitzFundamentalPriceShockMain();
		FCNMarkowitzPortfolioAgent.register(sim);
		FCNBaselMarkowitzPortfolioAgent.register(sim);
		PortfolioMarket.register(sim);
		new SequentialRunner(sim).run(args);
	}

	public def createEvents(json:JSON.Value):List[Event] {
		//Console.OUT.println("# event");
		val random = new JSONRandom(getRandom());
		val events = new ArrayList[Event]();
		if (!json("enabled").toBoolean()) {
			return events;
		}
		if (json("class").equals("FundamentalPriceShock")) {
			//Console.OUT.println("# priceShock");
			val shock = new FundamentalPriceShock();
			setupFundamentalPriceShock(shock, json, random);
			events.add(shock);

			Console.OUT.println("# " + json("class").toString() + " : " + JSON.dump(json));
		}

		return events;
	}

	public def setupFundamentalPriceShock(shock:FundamentalPriceShock, json:JSON.Value, random:JSONRandom) {
		val market = getMarketByName(json("target"));
		shock.marketId = market.id;
		shock.triggerTime = new ArrayList[Long]();
		shock.triggerTime.add(json("triggerDays").toLong()*CONFIG("numStepsOneDay").toLong());
		shock.shockTimeLength = FundamentalPriceShock.NO_TIME_LENGTH;
		shock.priceChangeRate = new ArrayList[Double]();
		shock.priceChangeRate.add(json("priceChangeRate").toDouble());
		market.addBeforeSimulationStepEvent(shock);
	}
}
