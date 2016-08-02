package seminar;
import x10.util.ArrayList;
import x10.util.List;
import x10.util.StringUtil;
import plham.Agent;
import plham.Main;
import plham.Market;
import seminar.FCNAgent;
import plham.util.JSON;
import plham.util.JSONRandom;
import plham.main.SequentialRunner;

public class CI2002Main extends Main {

	public static def main(args:Rail[String]) {
		new SequentialRunner(new CI2002Main()).run(args);
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
				"", ""], " ", "", Int.MAX_VALUE));
		}
	}

	public def createAgents(json:JSON.Value):List[Agent] {
		val random = new JSONRandom(getRandom());
		val agents = new ArrayList[Agent]();
		if (json("class").equals("FCNAgent")) {
			/* ？？？ */
		}
		return agents;
	}

	public def createMarkets(json:JSON.Value):List[Market] {
		val random = new JSONRandom(getRandom());
		val markets = new ArrayList[Market]();
		if (json("class").equals("Market")) {
			val market = new Market();
			setupMarket(market, json, random);
			markets.add(market);

			Console.OUT.println("# " + json("class").toString() + " : " + JSON.dump(json));
		}
		return markets;
	}

	public def setupFCNAgent(agent:FCNAgent, json:JSON.Value, random:JSONRandom) {
		val MARGIN_TYPES = JSON.parse("{'fixed': " + FCNAgent.MARGIN_FIXED + ", 'normal': " + FCNAgent.MARGIN_NORMAL + "}");

		agent.fundamentalWeight = random.nextRandom(json("fundamentalWeight"));
		agent.chartWeight = random.nextRandom(json("chartWeight"));
		agent.noiseWeight = random.nextRandom(json("noiseWeight"));
		agent.isChartFollowing = (random.nextDouble() < 1.0); // 100%

		agent.noiseScale = random.nextRandom(json("noiseScale"));
		agent.timeWindowSize = random.nextRandom(json("timeWindowSize")) as Long;
		agent.orderMargin = random.nextRandom(json("orderMargin"));
		agent.marginType = MARGIN_TYPES(json("marginType", "fixed")).toLong();

		for (market in getMarketsByName(json("markets"))) {
			agent.setMarketAccessible(market);
			agent.setAssetVolume(market, random.nextRandom(json("assetVolume")) as Long);
		}
		agent.setCashAmount(random.nextRandom(json("cashAmount")));
//		assert json("markets").size() == 1 : "FCNAgents suppose only one Market";
//		val market = getMarketByName(json("markets")(0));
//		agent.setMarketAccessible(market);
//		agent.setAssetVolume(market, random.nextRandom(json("assetVolume")) as Long);
//		agent.setCashAmount(random.nextRandom(json("cashAmount")));
	}

	public def setupMarket(market:Market, json:JSON.Value, random:JSONRandom) {
		market.setTickSize(random.nextRandom(json("tickSize", "-1.0"))); // " tick-size <= 0.0 means no tick size.
		market.setInitialMarketPrice(random.nextRandom(json("marketPrice")));
		market.setInitialFundamentalPrice(random.nextRandom(json("marketPrice")));
		market.setOutstandingShares(random.nextRandom(json("outstandingShares")) as Long);
	}
}
