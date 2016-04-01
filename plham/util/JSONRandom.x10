package plham.util;
import x10.util.Random;
import cassia.util.JSON;

/**
 * JSONRandom extends RandomHelper to provide integrated usability with JSON.
 */
public class JSONRandom extends RandomHelper {

	public def this(random:Random) {
		super(random);
	}

	/**
	 * Return a random number from a probability distribution specified in the JSON.Value.
	 * If it is a constant, return the value.
	 * If it is a list (pair), return a uniform random number between them.
	 * If it is a dict (of one key), return a random number sampled from a distribution given by the key name:
	 * 
	 *   * "const": [value]       ... constant, the value.
	 *   * "uniform": [min, max]  ... uniform between min and max.
	 *   * "normal": [mu, sigma]  ... normal of mean mu and variance sigma^2.
	 *   * "expon": [lambda]      ... exponential of expected lambda.
	 */
	public def nextRandom(json:JSON.Value):Double {
		if (json.isList()) {
			assert json.size() == 2 : "Uniform distribution must be [min, max] but " + JSON.dump(json);
			val min = json(0).toDouble();
			val max = json(1).toDouble();
			return this.nextUniform(min, max);
		}
		if (json.isMap()) {
			assert json.size() == 1 : "Multiple speficiation of distribution type: " + JSON.dump(json);
			if (json.has("const")) {
				val args = json("const");
				assert args.size() == 1 : "Constant must be [value] but " + JSON.dump(json);
				val value = args(0).toDouble();
				return value;
			}
			if (json.has("uniform")) {
				val args = json("uniform");
				assert args.size() == 2 : "Uniform distribution must be [min, max] but " + JSON.dump(json);
				val min = args(0).toDouble();
				val max = args(1).toDouble();
				return this.nextUniform(min, max);
			}
			if (json.has("normal")) {
				val args = json("normal");
				assert args.size() == 2 : "Normal distribution must be [mu, sigma] but " + JSON.dump(json);
				val mu = args(0).toDouble();
				val sigma = args(1).toDouble();
				return this.nextNormal(mu, sigma);
			}
			if (json.has("expon")) {
				val args = json("expon");
				assert args.size() == 1 : "Exponential distribution must be [lambda] but " + JSON.dump(json);
				val lambda = args(0).toDouble();
				return this.nextExponential(lambda);
			}
			assert false : "Unknown distribution type: " + JSON.dump(json);
		}
		return json.toDouble(); // WARN: CONSTANT
	}
}
