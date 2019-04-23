package samples.Parallel;
import x10.util.ArrayList;
import x10.util.List;
import plham.Agent;
import plham.Env;
import plham.Event;
import plham.Market;
import plham.IndexMarket;
import plham.agent.FCNAgent;
import plham.util.JSON;
import plham.util.JSONRandom;
import samples.ShockTransfer.ArbitrageAgent;
import samples.ShockTransfer.ShockTransferMain;
import plham.main.ParallelRunnerDist;

public class ParallelDistMain extends ShockTransferMain {

	public static def main(args:Rail[String]) {
		val runner = new ParallelRunnerDist[ParallelDistMain](() => new ParallelDistMain().loadClasses());
		runner.run(args);
	}

	def loadClasses(): ParallelDistMain {
		FCNAgent.register(this);
		Market.register(this);
		IndexMarket.register(this);
		plham.util.AgentGeneratorForEachMarket.register(this);
		ArbitrageAgent.register(this);
		WorkloadFCNAgent.register(this);
		plham.util.SimpleMarketGenerator.register(this);
		return this;
	}

	public def createEvents(json:JSON.Value):List[Event] {
		val events = new ArrayList[Event]();
		return events;
	}
}

// Local Variables:
// indent-tabs-mode: t
// tab-width: 4
// End:
