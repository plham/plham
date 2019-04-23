package samples.InvestDiv;
import x10.util.ArrayList;
import x10.util.List;
import x10.util.StringUtil;
import plham.Agent;
import plham.Event;
import plham.Market;
import plham.util.JSON;
import plham.util.JSONRandom;
import samples.TradingHalt.TradingHaltMain;
import plham.main.SequentialRunner;

/**
 * Reference: Nozaki, Mizuta, Yagi (2016) Investigation of the rule for investment diversification at the time of a market crash using an artificial market (in Japanese).
 */
public class InvestDivMain extends TradingHaltMain {

	public static def main(args:Rail[String]) {
		val sim = new InvestDivMain();
		InvestDivFCNAgent.register(sim);
		new SequentialRunner(sim).run(args);
	}
	
}
