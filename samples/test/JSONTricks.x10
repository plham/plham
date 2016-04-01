package plham.samples.test;
import plham.util.JSON;

public class JSONTricks {

	public static def main(Rail[String]) {
		val KEY_A = 0;
		val KEY_B = 1;
		val json = JSON.parse("{'A': " + KEY_A + ", 'B': " + KEY_B + "}");

		Console.OUT.println(json("A").toString());
		Console.OUT.println(json("B").toString());
	}
}
