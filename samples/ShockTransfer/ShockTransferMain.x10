package samples.ShockTransfer;
import x10.util.ArrayList;
import x10.util.List;
import x10.util.StringUtil;
import plham.Agent;
import plham.Event;
import plham.IndexMarket;
import plham.Main;
import plham.Market;
import plham.agent.ArbitrageAgent;
import plham.agent.FCNAgent;
import plham.index.CapitalWeightedIndexScheme;
import plham.event.FundamentalPriceShock;
import plham.util.JSON;
import plham.util.JSONRandom;
import samples.CI2002.CI2002Main;
import plham.main.SequentialRunner;

public class ShockTransferMain extends CI2002Main {

	public static def main(args:Rail[String]) {
		new SequentialRunner(new ShockTransferMain()).run(args);
	}

	public def print(sessionName:String) {
		val markets = getMarketsByName("markets");
		val agents = getAgentsByName("agents");
		for (market in markets) {
			val t = market.getTime();
			var marketIndex:Double = Double.NaN;
			if (market instanceof IndexMarket) {
				marketIndex = (market as IndexMarket).getIndex();
			}

			Console.OUT.println(StringUtil.formatArray([
				sessionName,
				t, 
				market.id,
				market.name,
				market.getPrice(t),
				market.getFundamentalPrice(t),
				marketIndex,
				"", ""], " ", "", Int.MAX_VALUE));
		}
	}

	public def createAgents(json:JSON.Value):List[Agent] {
		val random = new JSONRandom(getRandom());
		val agents = super.createAgents(json); // Use FCNAgent defined in CI2002Main.
		if (json("class").equals("ArbitrageAgent")) {
			val numAgents = json("numAgents").toLong();
			for (i in 0..(numAgents - 1)) {
				val agent = new ArbitrageAgent();
				setupArbitrageAgent(agent, json, random);
				agents.add(agent);
			}
			Console.OUT.println("# " + json("class").toString() + " : " + JSON.dump(json));
		}
		return agents;
	}

	public def createMarkets(json:JSON.Value):List[Market] {
		val random = new JSONRandom(getRandom());
		val markets = super.createMarkets(json); // Use Market defined in CI2002Main.
		if (json("class").equals("IndexMarket")) {
			val market = new IndexMarket();
			setupIndexMarket(market, json, random);
			markets.add(market);

			Console.OUT.println("# " + json("class").toString() + " : " + JSON.dump(json));
		}
		return markets;
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
		return events;
	}

	public def setupArbitrageAgent(agent:ArbitrageAgent, json:JSON.Value, random:JSONRandom) {
		agent.orderVolume = json("orderVolume").toLong();
		agent.orderThresholdPrice = json("orderThresholdPrice").toDouble();

		assert json("markets").size() == 1 : "ArbitrageAgents suppose only one IndexMarket";
		assert getMarketByName(json("markets")(0)) instanceof IndexMarket : "ArbitrageAgents suppose only one IndexMarket";
		val market = getMarketByName(json("markets")(0)) as IndexMarket;
		agent.setMarketAccessible(market);
		for (id in market.getComponents()) {
			agent.setMarketAccessible(id);
		}

		agent.setAssetVolume(market, random.nextRandom(json("assetVolume")) as Long);
		for (id in market.getComponents()) {
			agent.setAssetVolume(id, random.nextRandom(json("assetVolume")) as Long);
		}
		agent.setCashAmount(random.nextRandom(json("cashAmount")));
	}

	public def setupIndexMarket(market:IndexMarket, json:JSON.Value, random:JSONRandom) {
		market.setTickSize(random.nextRandom(json("tickSize", "-1.0"))); // " tick-size <= 0.0 means no tick size.

		val spots = getMarketsByNames(json("markets"));
		market.addMarkets(spots);

		// WARN: Market's methods access to market.env is not available here :WARN

		val marketIndex = new CapitalWeightedIndexScheme(CapitalWeightedIndexScheme.MARKET_PRICE);
		marketIndex.setIndexDivisor(random.nextRandom(json("marketPrice")), marketIndex.getIndex(spots));
		market.setMarketIndexScheme(marketIndex);

		val fundamIndex = new CapitalWeightedIndexScheme(CapitalWeightedIndexScheme.FUNDAMENTAL_PRICE);
		fundamIndex.setIndexDivisor(random.nextRandom(json(["fundamentalPrice", "marketPrice"])), fundamIndex.getIndex(spots));
		market.setFundamentalIndexScheme(fundamIndex);

		market.setInitialMarketPrice(marketIndex.getIndex(spots));
		market.setInitialMarketIndex(marketIndex.getIndex(spots));
		market.setInitialFundamentalPrice(fundamIndex.getIndex(spots));
		market.setInitialFundamentalIndex(fundamIndex.getIndex(spots));
		market.setOutstandingShares(random.nextRandom(json("outstandingShares")) as Long);
	}

	public def setupFundamentalPriceShock(shock:FundamentalPriceShock, json:JSON.Value, random:JSONRandom) {
		val market = getMarketByName(json("target"));
		shock.marketId = market.id;
		shock.triggerTime = json("triggerTime").toLong();
		shock.shockTimeLength = FundamentalPriceShock.NO_TIME_LENGTH;
		shock.priceChangeRate = json("priceChangeRate").toDouble();
		market.addBeforeSimulationStepEvent(shock);
	}
}
