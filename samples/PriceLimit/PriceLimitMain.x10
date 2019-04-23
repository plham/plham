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
		val sim = new PriceLimitMain();
		PriceLimitFCNAgent.register(sim);
		Market.register(sim);
		PriceLimitRule.register(sim);
		new SequentialRunner(sim).run(args);
	}

}
