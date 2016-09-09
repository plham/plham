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
		new SequentialRunner(new InvestDivMain()).run(args);
	}

	public def createAgents(json:JSON.Value):List[Agent] {
		val random = new JSONRandom(getRandom());
		val agents = super.createAgents(json);
		if (json("class").equals("InvestDivFCNAgent")) {
			val numAgents = json("numAgents").toLong();
			for (i in 0..(numAgents - 1)) {
				val agent = new InvestDivFCNAgent();
				setupInvestDivFCNAgent(agent, json, random);
				agents.add(agent);
			}
			Console.OUT.println("# " + json("class").toString() + " : " + JSON.dump(json));
		}
		return agents;
	}

	public def setupInvestDivFCNAgent(agent:InvestDivFCNAgent, json:JSON.Value, random:JSONRandom) {
		setupFCNAgent(agent, json, random);
		agent.leverageRatio = json("leverageRatio").toDouble();
		agent.diversityRatio = json("diversityRatio").toDouble();
	}
}
