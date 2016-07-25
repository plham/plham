package samples.FatTail;
import samples.CI2002Main;
import plham.main.SequentialRunner;

public class FatTailMain extends CI2002Main {

	public static def main(args:Rail[String]) {
		new SequentialRunner(new FatTailMain()).run(args);
	}
}
