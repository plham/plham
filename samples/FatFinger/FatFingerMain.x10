package samples.FatFinger;
import x10.util.ArrayList;
import x10.util.List;
import x10.util.StringUtil;
import plham.Agent;
import plham.Market;
import plham.Event;
import plham.agent.FCNAgent;
import plham.event.OrderMistakeShock;
import plham.util.JSON;
import plham.util.JSONRandom;
import plham.main.SequentialRunner;
import samples.CI2002.CI2002Main;

public class FatFingerMain extends CI2002Main {

	public static def main(args:Rail[String]) {
		val sim = new FatFingerMain();
		FCNAgent.register(sim);
		Market.register(sim);
		OrderMistakeShock.register(sim);
		new SequentialRunner(sim).run(args);
	}

	public def print(sessionName:String) {
		super.print(sessionName);
		val markets = getMarketsByName("markets");
		for (market in markets) {
			market.getBuyOrderBook().dump();  /* WARNING: This dumps all orders in the orderbook!! */
			market.getSellOrderBook().dump(); /* WARNING: This dumps all orders in the orderbook!! */
		}
	}

}
