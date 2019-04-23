package plham.util;
import x10.util.ArrayList;
import x10.util.List;
import x10.util.Random;
import plham.Agent;
import plham.Market;
import plham.main.Simulator;
import plham.util.Itayose;
import plham.util.JSON;
import plham.util.JSONRandom;

public class AgentGeneratorForEachMarket {
	public static def register(sim:Simulator):void {
		val className = "AgentGeneratorForEachMarket";
		sim.addAgentGenerator(className, (json:JSON.Value):List[JSON.Value] => {
			assert(json.has("markets"));
			val markets = new ArrayList[Market]();
			val marketNames = json("markets").asList();
			for (marketName in marketNames) { // marketName :: JSON.Value
				val name = marketName.toString();
				markets.addAll(sim.getMarketsByName(name));
			}
			assert(json.has("base"));
			val agentConfigs = new ArrayList[JSON.Value]();
			for (market in markets) {
				val agentConfig = json("base").apply([
					new JSON.Entry(
						"accessibleMarkets",
						JSON.parse("[" + market.name + "]")
					) as JSON.Entry,
					new JSON.Entry(
						"markets",
						JSON.parse("[" + market.name + "]")
					)
				] as Rail[JSON.Entry]);
				agentConfigs.add(agentConfig);
			}
			return agentConfigs as List[JSON.Value];
		});
	}
}

