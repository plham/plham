package samples.MarketShare;
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
 * Reference: Kusada, Mizuta, Hayakawa, Izumi, Yoshimura (2014) Analysis of the market makers spread's impact to markets volume shares using an artificial market (in Japanese).
 */
public class MarketShareMain extends CI2002Main {

	public static def main(args:Rail[String]) {
		new SequentialRunner(new MarketShareMain()).run(args);
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
				market.getTradeVolume(t),
				"", ""], " ", "", Int.MAX_VALUE));
		}
	}

	public def createAgents(json:JSON.Value):List[Agent] {
		val random = new JSONRandom(getRandom());
		val agents = super.createAgents(json); // Use FCNAgent defined in CI2002Main.
		if (json("class").equals("MarketShareFCNAgent")) {
			val numAgents = json("numAgents").toLong();
			for (i in 0..(numAgents - 1)) {
				val agent = new MarketShareFCNAgent();
				setupMarketShareFCNAgent(agent, json, random);
				agents.add(agent);
			}
			Console.OUT.println("# " + json("class").toString() + " : " + JSON.dump(json));
		}
		if (json("class").equals("MarketMakerAgent")) {
			val numAgents = json("numAgents").toLong();
			for (i in 0..(numAgents - 1)) {
				val agent = new MarketMakerAgent();
				setupMarketMakerAgent(agent, json, random);
				agents.add(agent);
			}
			Console.OUT.println("# " + json("class").toString() + " : " + JSON.dump(json));
		}
		return agents;
	}

	public def setupMarketShareFCNAgent(agent:MarketShareFCNAgent, json:JSON.Value, random:JSONRandom) {
		setupFCNAgent(agent, json, random); // Nothing new
	}

	public def setupMarketMakerAgent(agent:MarketMakerAgent, json:JSON.Value, random:JSONRandom) {
		val targetMarket = getMarketByName(json("targetMarket"));
		agent.targetMarketId = targetMarket.id;
		agent.netInterestSpread = random.nextRandom(json("netInterestSpread"));
		agent.orderTimeLength = random.nextRandom(json("orderTimeLength", "2")) as Long;

		for (market in getMarketsByName(json("markets"))) {
			agent.setMarketAccessible(market);
			agent.setAssetVolume(market, random.nextRandom(json("assetVolume")) as Long);
		}
		agent.setCashAmount(random.nextRandom(json("cashAmount")));
	}

	// Defined in CI2002Main.
	public def setupMarket(market:Market, json:JSON.Value, random:JSONRandom) {
		super.setupMarket(market, json, random);
		market.setTradeVolume(0, random.nextRandom(json("tradeVolume")) as Long);
	}
}
