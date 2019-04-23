package samples.ShockTransferPort;
import x10.util.ArrayList;
import x10.util.List;
import x10.util.Random;
import x10.util.StringUtil;
import plham.Agent;
import plham.Env;
import plham.Fundamentals;
import plham.event.FundamentalPriceShock;
import plham.Market;
import plham.IndexMarket;
import plham.Order;
import plham.Event;
import samples.ShockTransferPort.FCNMarkowitzPortfolioAgent;
import cassia.util.JSON;
import x10.util.Map;
import x10.util.HashMap;
import plham.main.SequentialRunner;
import plham.Main;
import plham.util.JSONRandom;
import plham.util.SimpleMarketGenerator;
import plham.util.AgentGeneratorForEachMarket;
import samples.ShockTransferPort.FCNMarkowitzCI2002Main;

public class FCNMarkowitzFundamentalPriceShockMain extends FCNMarkowitzCI2002Main {

	public static def main(args:Rail[String]) {
		val sim = new FCNMarkowitzFundamentalPriceShockMain();
		Market.register(sim);
		IndexMarket.register(sim);
		SimpleMarketGenerator.register(sim);
		AgentGeneratorForEachMarket.register(sim);
		FCNMarkowitzPortfolioAgent.register(sim);
		FundamentalPriceShock.register(sim);
		new SequentialRunner(sim).run(args);
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
				(market.getPrice(t)/market.getFundamentalPrice(t)),
				"", ""], " ", "", Int.MAX_VALUE));
		}
	}
}

