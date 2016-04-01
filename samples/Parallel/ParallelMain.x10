package samples.Parallel;
import x10.util.ArrayList;
import x10.util.List;
import plham.Agent;
import plham.Env;
import plham.Event;
import plham.util.JSON;
import plham.util.JSONRandom;
import samples.ShockTransfer.ShockTransferMain;
import plham.main.ParallelRunnerProto;

public class ParallelMain extends ShockTransferMain {

	public static def main(args:Rail[String]) {
		new ParallelRunnerProto[ParallelMain](() => new ParallelMain()).run(args);
	}

	public def createAgents(json:JSON.Value):List[Agent] {
		val random = new JSONRandom(getRandom());
		val agents = super.createAgents(json); // Use FCNAgent and ArbitrageAgent defined in ShockTransferMain.
		if (json("class").equals("WorkloadFCNAgent")) {
			val numAgents = json("numAgents").toLong();
			for (i in 0..(numAgents - 1)) {
				val agent = new WorkloadFCNAgent();
				setupWorkloadFCNAgent(agent, json, random);
				agents.add(agent);
			}
			Console.OUT.println("# " + json("class").toString() + " : " + JSON.dump(json));
		}
		return agents;
	}

	public def setupWorkloadFCNAgent(agent:WorkloadFCNAgent, json:JSON.Value, random:JSONRandom) {
		setupFCNAgent(agent, json, random);
		agent.hasWorkload = Boolean.parse(Env.getenvOrElse("BS_WORKLOAD", "false"));
		agent.bsNSamples = Long.parse(Env.getenvOrElse("BS_NSAMPLES", "0"));
		agent.bsNSteps = Long.parse(Env.getenvOrElse("BS_NSTEPS", "0"));
		agent.orderRate = Double.parse(Env.getenvOrElse("ORDER_RATE", "0.1"));
	}

	public def createEvents(json:JSON.Value):List[Event] {
		val events = new ArrayList[Event]();
		return events;
	}
}
