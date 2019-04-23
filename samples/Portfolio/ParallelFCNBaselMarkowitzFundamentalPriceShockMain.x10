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
import cassia.util.JSON;
import x10.util.Map;
import x10.util.HashMap;
import plham.Main;
import plham.util.JSONRandom;
import plham.main.ParallelRunnerProto;
import plham.main.SequentialRunner;

public class ParallelFCNBaselMarkowitzFundamentalPriceShockMain extends FCNBaselMarkowitzFundamentalPriceShockMain {

	public static def main(args:Rail[String]) {
		new ParallelRunnerProto[ParallelFCNBaselMarkowitzFundamentalPriceShockMain](() => new ParallelFCNBaselMarkowitzFundamentalPriceShockMain()).run(args);
	}

}
