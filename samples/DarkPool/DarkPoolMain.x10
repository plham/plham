package samples.DarkPool;
import x10.util.ArrayList;
import x10.util.List;
import x10.util.StringUtil;
import plham.Agent;
import plham.Market;
import plham.util.JSON;
import plham.util.JSONRandom;
import samples.CI2002.CI2002Main;
import plham.main.SequentialRunner;

/**
 * Reference: Mizuta, Kosugi, Kusumoto, Matsumoto, Izumi (2014) Analysis of the impact of dark pool to the market efficiency using an artificial market (in Japanese).
 */
public class DarkPoolMain extends CI2002Main {

	public static def main(args:Rail[String]) {
		new SequentialRunner(new DarkPoolMain()).run(args);
	}

	public def print(sessionName:String) {
		val markets = getMarketsByName("markets");
		val agents = getAgentsByName("agents");

		assert markets.size() == 2;
		val lit = getMarketByName("LitMarket"); // Name defined in JSON file.
		val dark = getMarketByName("DarkPoolMarket");
		var tradePrice:Double = Double.NaN;
		if (dark.getTradeVolume() > 0) {
			tradePrice = dark.getPrice();
		} else if (lit.getTradeVolume() > 0) {
			tradePrice = lit.getPrice();
		}

		for (market in markets) {
			val t = market.getTime();
			Console.OUT.println(StringUtil.formatArray([
				sessionName,
				t, 
				market.id,
				market.name,
				market.getPrice(t),
				market.getFundamentalPrice(t),
				//
				tradePrice,
				market.getTradeVolume(),
				"", ""], " ", "", Int.MAX_VALUE));
		}
	}

	public def createAgents(json:JSON.Value):List[Agent] {
		val random = new JSONRandom(getRandom());
		val agents = super.createAgents(json); // Use FCNAgent defined in CI2002Main.
		if (json("class").equals("DarkPoolFCNAgent")) {
			val numAgents = json("numAgents").toLong();
			for (i in 0..(numAgents - 1)) {
				val agent = new DarkPoolFCNAgent();
				setupDarkPoolFCNAgent(agent, json, random);
				agents.add(agent);
			}
			Console.OUT.println("# " + json("class").toString() + " : " + JSON.dump(json));
		}
		return agents;
	}

	public def createMarkets(json:JSON.Value):List[Market] {
		val random = new JSONRandom(getRandom());
		val markets = super.createMarkets(json); // Use Market defined in CI2002Main.
		if (json("class").equals("DarkPoolMarket")) {
			val market = new DarkPoolMarket();
			setupDarkPoolMarket(market, json, random);
			markets.add(market);

			Console.OUT.println("# " + json("class").toString() + " : " + JSON.dump(json));
		}
		return markets;
	}

	public def setupDarkPoolFCNAgent(agent:DarkPoolFCNAgent, json:JSON.Value, random:JSONRandom) {
		setupFCNAgent(agent, json, random);
		agent.darkPoolChance = random.nextRandom(json("darkPoolChance"));
	}

	public def setupDarkPoolMarket(market:DarkPoolMarket, json:JSON.Value, random:JSONRandom) {
		setupMarket(market, json, random);
		assert json("markets").size() == 1;
		val lit = getMarketByName(json("markets")(0));
		market.setLitMarket(lit);
	}
}
