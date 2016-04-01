package samples.CancelTest;
import x10.util.List;
import plham.Agent;
import plham.Env;
import plham.Market;
import samples.CancelTest.CancelFCNAgent;
import plham.util.JSON;
import plham.util.JSONRandom;
import samples.CI2002.CI2002Main;
import plham.main.SequentialRunner;

public class CancelTestMain extends CI2002Main {

	public static def main(args:Rail[String]) {
		new SequentialRunner(new CancelTestMain()).run(args);
	}

	public def createAgents(json:JSON.Value):List[Agent] {
		val random = new JSONRandom(getRandom());
		val agents = super.createAgents(json);
		if (json("class").equals("CancelFCNAgent")) {
			val numAgents = json("numAgents").toLong();
			for (i in 0..(numAgents - 1)) {
				val agent = new CancelFCNAgent();
				setupFCNAgent(agent, json, random);
				agents.add(agent);
			}
			Console.OUT.println("# " + json("class").toString() + " : " + JSON.dump(json));
		}
		return agents;
	}
}
