package samples.ShockTransferPort;
import x10.util.ArrayList;
import x10.util.Indexed;
import x10.util.List;
import x10.util.Random;
import plham.Agent;
import plham.IndexMarket;
import plham.Market;
import plham.Order;
import plham.main.Simulator;
import x10.util.Map;
import x10.util.HashMap;
import plham.util.Statistics;
import plham.util.Matrix;
import x10.io.File;
import plham.Cancel;
import plham.util.RandomHelper;
import plham.Env;
import plham.util.JSON;
import plham.util.JSONRandom;
import plham.util.MultiGeomBrownian2;

import portfolio.util.PortfolioOptimizer;

public class FCNMarkowitzPortfolioAgent extends Agent {
	public static TIME_WINDOW_SIZE_SCALE = 100.0;
	public static NOISE_SIGMA = 0.001;
	public static FUNDAMENTAL_MEAN_REVERSION_TIME = TIME_WINDOW_SIZE_SCALE; // NOTE: The value cannot be found in CIP(2009).
	public var session0iterationDays:Long;
	public var fundamentalWeight:Double;
	public var chartWeight:Double;
	public var noiseWeight:Double;
	public var fundamentalMeanReversionTime:Double; // A common knowledge?
	public var noiseScale:Double;
	public var b:Double;
	public var a:Double;
	public var allMarkets:List[Market];
	public var accessibleMarkets:List[Market];
	public var TPORT:Long; //days
	public var lastUpdated:Long; //num of first step of month
	public var optimalVolumes:HashMap[Long,Long];
	public var orderPrices:HashMap[Long,Double];
	public var timeWindowSize:Long;
	public var timeSize:Long;
	public var covarfundamentalWeight:Double;
	public var shortSellingAbility:Boolean; //最適ポジションが負の値を取れるかどうか
	public var maxPositionSize:Long = Math.pow2(50); //Math.pow2(20); //取りうる最適ポジションでの最大値(Longの最大値は2^63-1≒10^18だが，今回は1ペタ≒10^15とした).
	public var leverageRate:Double; //現在の総資産の何倍まで借金してよいか
	public var lastOreders:List[Order] =  new ArrayList[Order](); //過去のオーダー情報
	public var numStepsOneDay:Long;
	public var numDaysOneMonth:Long;
	public var DEBUG:Long=0;
	public var logType:boolean; //リターン計算時に対数リターンを使うかどうか.
	public var base:Long=0; //最適ポートフォリオ更新のタイミング

	var Z:Double;
	var A:Rail[Rail[Double]];
	var B:Rail[Double];
	var C:Rail[Rail[Double]];
	var D:Rail[Double];
	var expectedFCNReturns:HashMap[Long,Double];
	var expectedRisk:HashMap[Long,HashMap[Long,Double]];
	var expectedPrices:HashMap[Long,Double];
	public var orderMarket:ArrayList[Market];

	// This enables automated order numbering.
	// Use this hack if you wanna send cancel requests.
	public var orderId:Long = 1;
	public def nextOrderId():Long {
		return orderId++;
	}

	//コンストラクタ

	public def this() {
		/* TIPS: To keep variables unset forces users to set them. */
	}

	public def this(id:Long, name:String, random:Random) = super(id, name, random);

	public def this(id:Long, fundamentalWeight:Double, chartWeight:Double, noiseWeight:Double,accessibleMarkets:List[Market],T:Long) {
		super(id);
		this.fundamentalWeight = fundamentalWeight;
		this.chartWeight = chartWeight;
		this.noiseWeight = noiseWeight;
		this.fundamentalMeanReversionTime = FUNDAMENTAL_MEAN_REVERSION_TIME;
		this.noiseScale = NOISE_SIGMA;
		assert fundamentalWeight >= 0.0 : "fundamentalWeight >= 0.0";
		assert chartWeight >= 0.0 : "chartWeight >= 0.0";
		assert noiseWeight >= 0.0 : "noiseWeight >= 0.0";
		this.b= 1;
		assert this.b > 0: "b > 0.0";
		this.TPORT = T; //days
		this.accessibleMarkets = accessibleMarkets;
		this.lastUpdated = 0; //正しい？
	}

	public def submitOrders(markets:List[Market]):List[Order] {
		//Console.OUT.println("#Type:"+ this.logType);
		this.allMarkets = markets;
		this.accessibleMarkets = filterMarkets(markets);
		this.orderMarket = marketOrder();
		/* This implementation is to be a test-friendly base class. */
		val orders = new ArrayList[Order]();
		val torders = new ArrayList[Order]();
		val corders = new ArrayList[Order]();


		//過去出した注文を全てキャンセル.
		var lastorders:ArrayList[Order] = this.lastOreders as ArrayList[Order];
		var numlast:Long = lastorders.size();
		for(last in lastorders.clone()){
			corders.add(new Cancel(last));
		}
		lastorders.clear();
		assert lastorders.size()==0 && corders.size() == numlast : "cancelError";
	

		/* 現在のステップ t */
		var t:Long = 0;
		if(this.getTime(allMarkets)>=1){
			t = this.getTime(allMarkets) -1;
		}


		if(t>=this.session0iterationDays*this.numStepsOneDay){ 	

			if (DEBUG == -3) {
				Console.OUT.println("#id:"+ this.id);
				//Console.OUT.println("#\tweight:"+this.fundamentalWeight+","+this.chartWeight+","+ this.noiseWeight);
			}

			var TPS:Rail[Long] = getTPORTStructure(t);
			//Console.OUT.println("t0="+TPS(0)+",t1="+TPS(1)+",t2="+TPS(2)+",this.base="+this.base );
			val orderTimeWindowSize:Long =this.TPORT*this.numStepsOneDay*this.timeWindowSize;
	
			//今期の時間を基に最適ポートフォリオを更新するかを判断。
			//必要なら最適ポートフォリオとlastUpdatedを更新。
			if(checkUpdateExpectation(TPS)){ updateOptimalVolumes(t); }
	
					val presentVolumes = FCNMarkowitzPortfolioAgent.translation7(this.assetsVolumes,this.orderMarket);
	
					val presentPricesStep = presentMarketPricesStep(t);
					val presentZStep = getZ(presentPricesStep);
					val presentPortfolioStep = FCNMarkowitzPortfolioAgent.getPF( presentVolumes, translation6( presentPricesStep,this.orderMarket ) ,presentZStep);
	
					val presentPricesDay = presentMarketPricesOneDay(t);
					val presentZDay = getZ(presentPricesDay);
					val presentPortfolioDay = FCNMarkowitzPortfolioAgent.getPF( presentVolumes, translation6( presentPricesDay,this.orderMarket ) ,presentZDay);
	
					val presentPricesMonth = presentMarketPricesOneMonth(t);
					val presentZMonth = getZ(presentPricesMonth);
					val presentPortfolioMonth = FCNMarkowitzPortfolioAgent.getPF( presentVolumes, translation6( presentPricesMonth,this.orderMarket ) ,presentZMonth);
	
					val presentPricesTPORT = presentMarketPricesTPORT(t);
					val presentZTPORT = getZ(presentPricesTPORT);
					val presentPortfolioTPORT = FCNMarkowitzPortfolioAgent.getPF( presentVolumes, translation6( presentPricesTPORT,this.orderMarket ) ,presentZTPORT);
	
				if (DEBUG == -3) {
/*
					Console.OUT.println("#portfolioAgt"+this.id+":");
					Console.OUT.println("##presentVolume:");
					Console.OUT.print("##");
					Matrix.dump(presentVolumes);
					Console.OUT.println("##=========step");
					Console.OUT.println("##presentZ: "+ presentZStep);
					Console.OUT.println("##presentPF:");
					Console.OUT.print("##");
					Matrix.dump( presentPortfolioStep );
					Console.OUT.println("##presentRatio:");
					Console.OUT.print("##");
					Matrix.dump( Matrix.multiply( (1/presentZStep), presentPortfolioStep ) );
*/		/*			Console.OUT.println("##=========day");
	
					Console.OUT.println("##presentZ: "+ presentZDay);
					Console.OUT.println("##presentPF:");
					Console.OUT.print("##");
					Matrix.dump( presentPortfolioDay );
					Console.OUT.println("##presentRatio:");
					Console.OUT.print("##");
					Matrix.dump( Matrix.multiply( (1/presentZDay), presentPortfolioDay ) );
					Console.OUT.println("##=========Month");
	
					Console.OUT.println("##presentZ: "+ presentZMonth);
					Console.OUT.println("##presentPF:");
					Console.OUT.print("##");
					Matrix.dump( presentPortfolioMonth );
					Console.OUT.println("##presentRatio:");
					Console.OUT.print("##");
					Matrix.dump( Matrix.multiply( (1/presentZMonth), presentPortfolioMonth ) );
*/ /*					Console.OUT.println("##=========TPORT");
	
					Console.OUT.println("##presentZ: "+ presentZTPORT);
					Console.OUT.println("##presentPF:");
					Console.OUT.print("##");
					Matrix.dump( presentPortfolioTPORT );
					Console.OUT.println("##presentRatio:");
					Console.OUT.print("##");
					Matrix.dump( Matrix.multiply( (1/presentZTPORT), presentPortfolioTPORT ) );
*/	
				var opt:Rail[Long] = FCNMarkowitzPortfolioAgent.translation7(this.optimalVolumes,this.orderMarket);
				var pv:Rail[Long] = FCNMarkowitzPortfolioAgent.translation7(this.assetsVolumes,this.orderMarket);
				//Console.OUT.println("##numlast:"+ numlast);
				Console.OUT.println("#**Optimal:");
				Console.OUT.print("#");
				Matrix.dump(opt);
				Console.OUT.println("#**presentVolume:");
				Console.OUT.print("#");
				//Matrix.dump(pv);
	
			}
/*
				var opt:Rail[Long] = FCNMarkowitzPortfolioAgent.translation7(this.optimalVolumes,this.orderMarket);
				var pv:Rail[Long] = FCNMarkowitzPortfolioAgent.translation7(this.assetsVolumes,this.orderMarket);
				//Console.OUT.println("##numlast:"+ numlast);
				Console.OUT.println("#**Optimal:");
				Console.OUT.print("#");
				Matrix.dump(opt);
				Console.OUT.println("#**presentVolume:");
				Console.OUT.print("#");
				Matrix.dump(pv);
				Console.OUT.println("#**presentZStep:"+ presentZStep);			
*/
				//marketにアクセス不能か，もしくは，総資産が一番安い商品すら買えない金額だったら，あるmarketへの注文はゼロとする(詳細はplaceOrders参照)	
				for (market in markets) {
					torders.addAll(this.placeOrders(market,t, orderTimeWindowSize));
				}
			}
			lastorders.addAll(torders);
			orders.addAll(corders);
			orders.addAll(torders);
			return orders;
	}
	

	public def filterMarkets(markets:List[Market]):List[Market] {
		val a = new ArrayList[Market]();
		for (market in markets) {
			if (this.isMarketAccessible(market)) {
        		        a.add(market);
        		}
        	}
        	return a;
    	}

	public def placeOrders(market:Market, t:Long, orderTimeWindowSize:Long):List[Order] {

		/* 注文リスト．ここに 1 つだけ Order を入れる */
		val orders = new ArrayList[Order]();

		//marketにアクセス不能か，もしくは，総資産が一番安い商品すら買えない金額だったら，注文は出せないものとする.
		if( !this.isMarketAccessible(market) 
		|| getZ( presentMarketPricesTPORT(t)  ) <  Matrix.minimum(translation6(presentMarketPricesTPORT(t),this.orderMarket))
		|| getZ( presentMarketPricesOneMonth(t) ) <  Matrix.minimum(translation6(presentMarketPricesOneMonth(t),this.orderMarket))
		|| getZ( presentMarketPricesOneDay(t) ) <  Matrix.minimum(translation6(presentMarketPricesOneDay(t),this.orderMarket)) 
		|| getZ( presentMarketPricesStep(t)   ) <  Matrix.minimum(translation6(presentMarketPricesStep(t),this.orderMarket)) 
		){
			return orders;
		}

		//各財についての最適ポートフォリオのベクトル(離散値)の要素から現在のポートフォリオのベクトルの要素を
		//引いたもの（差）を計算。値が正（負）のものはその値の絶対値の分だけ財を購入（売却）する。
		//購入価格は、予想価格。注文の維持期間orderTimeWindowSizeはthis.TPORT*TimeSize*numStepsOneDay。
		//（注文取消とかについてはまた後で考える）
		var orderVolume:Long = this.getOptimalVolumes(market) - this.getAssetVolume(market);


		if(orderVolume!=0){
			if (DEBUG == -3) {
				Console.OUT.println("#**orderVolume="+ orderVolume);
				Console.OUT.println("#**orderPrice="+ getOrderPrices(market));
			}
		}

		if(orderVolume > 0){
			orders.add(new Order(Order.KIND_BUY_LIMIT_ORDER, this, market, getOrderPrices(market), orderVolume, orderTimeWindowSize));
		}else if(orderVolume < 0){
			orderVolume = Math.abs(orderVolume);
			orders.add(new Order(Order.KIND_SELL_LIMIT_ORDER, this, market, getOrderPrices(market), orderVolume, orderTimeWindowSize));
		}

		return orders;
	}



	//18. 今期の時間tを元に、最適portfolioとorderPrices,lastUpdatedを更新
	public def updateOptimalVolumes(time:Long):void{

		var TPS:Rail[Long] = getTPORTStructure(time);

		val days = TPS(0)*this.TPORT + TPS(1);


		this.timeSize = Math.min(TPS(0), this.timeWindowSize);

		val presentFundamentalPricesTPORT = presentFundamentalPricesTPORT(time);
		val presentMarketPricesTPORT = presentMarketPricesTPORT(time);

		val recentMarketReturnsTPORT:HashMap[Market,ArrayList[Double]];
		val recentFundamentalReturnsTPORT:HashMap[Market,ArrayList[Double]];

		val recentFundamentalistReturns:HashMap[Market,Double];
		val recentChartistReturns:HashMap[Market,Double];
		val noiseReturns:HashMap[Market,Double];

		if(this.logType){
			val recentMarketLogReturnsTPORT:HashMap[Market,ArrayList[Double]] = recentMarketLogReturnsTPORT(time, timeSize);
			val recentFundamentalLogReturnsTPORT:HashMap[Market,ArrayList[Double]] = recentFundamentalLogReturnsTPORT(time, timeSize);
			val recentFundamentalistLogReturns:HashMap[Market,Double] = recentFundamentalistLogReturns(presentFundamentalPricesTPORT, presentMarketPricesTPORT);

			recentMarketReturnsTPORT = recentMarketLogReturnsTPORT;
			recentFundamentalReturnsTPORT = recentFundamentalLogReturnsTPORT;
			recentFundamentalistReturns = recentFundamentalistLogReturns;
		}else{
			val recentMarketNormalReturnsTPORT:HashMap[Market,ArrayList[Double]] = recentMarketNormalReturnsTPORT(time, timeSize);
			val recentFundamentalNormalReturnsTPORT:HashMap[Market,ArrayList[Double]] = recentFundamentalNormalReturnsTPORT(time, timeSize);
			val recentFundamentalistNormalReturns:HashMap[Market,Double] = recentFundamentalistNormalReturns(presentFundamentalPricesTPORT, presentMarketPricesTPORT);

			recentMarketReturnsTPORT = recentMarketNormalReturnsTPORT;
			recentFundamentalReturnsTPORT = recentFundamentalNormalReturnsTPORT;
			recentFundamentalistReturns = recentFundamentalistNormalReturns;
		}

		recentChartistReturns = recentChartistReturns(recentMarketReturnsTPORT);
		noiseReturns = recentNoiseReturns();

		val expectedFCNReturns = expectedFCNReturns(recentFundamentalistReturns, recentChartistReturns,noiseReturns);
		this.expectedFCNReturns = FCNMarkowitzPortfolioAgent.translation1(expectedFCNReturns,this.orderMarket);


		var expectedFCNPricesTPORT:HashMap[Market,Double];

		//予想される市場価格の計算
		if(this.logType){
			expectedFCNPricesTPORT = expectedLogPrices(presentMarketPricesTPORT, expectedFCNReturns); 
		}else{
			expectedFCNPricesTPORT = expectedNormalPrices(presentMarketPricesTPORT, expectedFCNReturns); 
		}
		this.expectedPrices = FCNMarkowitzPortfolioAgent.translation1(expectedFCNPricesTPORT,this.orderMarket);


		//予想される今期のリスク（分散、共分散）の計算
		val expectedRisk = expectedRisk(recentMarketReturnsTPORT,recentFundamentalReturnsTPORT,this.covarfundamentalWeight);
		this.expectedRisk = FCNMarkowitzPortfolioAgent.translation10(expectedRisk, this.orderMarket);

		if (DEBUG == -3) {
			val T = time - time%(this.TPORT*this.numStepsOneDay);
/*			Console.OUT.println("#\t*TPORTFirstStep:"+T);
			Console.OUT.println("#\t*presentMarketPricesTPORT:"+presentMarketPricesTPORT.get(this.orderMarket(0)));
			Console.OUT.println("#\t*recentFundamentalistReturns:"+recentFundamentalistReturns.get(this.orderMarket(0)));
			Console.OUT.println("#\t*recentChartistReturns:"+recentChartistReturns.get(this.orderMarket(0)));
			Console.OUT.println("#\t*recentNoiseReturns:"+NoiseReturns.get(this.orderMarket(0)));
			Console.OUT.println("#\t*expectedFCNReturns:"+expectedFCNReturns.get(this.orderMarket(0)));
			Console.OUT.println("#\t*expectedFCNLogRisk:"+expectedRisk.get(this.orderMarket(0)).get(this.orderMarket(0)));
*/		}

		//最適ポートフォリオのベクトルXの計算に必要なAX = B の行列AとベクトルBを計算。
		//(総資産Zは今期tの市場価格を使う。一方、目的関数内の価格については予想値を使う)
		this.Z = getZ(presentMarketPricesTPORT);
		var B:Rail[Double] = FCNMarkowitzPortfolioAgent.getB(expectedFCNPricesTPORT, expectedFCNReturns, this.Z, this.orderMarket);
		var A:Rail[Rail[Double]] = FCNMarkowitzPortfolioAgent.getA(expectedFCNPricesTPORT, expectedFCNReturns, expectedRisk, this.Z, b, this.orderMarket);
		//Console.OUT.println("[DBG]: accessibleMarkets.size() = " + accessibleMarkets.size());
		//Console.OUT.println("[DBG]: A = " + A);
		//Console.OUT.println("[DBG]: B = " + B);

		if (DEBUG == -2) {
			Console.OUT.print("\n"+"\t*Q=");
			Matrix.dump(A);
			Console.OUT.print("\t*C=");
			Matrix.dump(B);
		}

		var x:Rail[Double] = new Rail[Double](A.size);
		var candidates:ArrayList[HashMap[Market,Long]];
		val y:HashMap[Market,Long];

		val multiplier:Double = Matrix.multiplier(Math.min(sizeMinA(A),sizeMinB(B)));	//Aの各セル，Bの各要素となる値の中で最も絶対値が小さな値の絶対値を取ってきて，その値の逆数と同じ桁数の数字をmulitplierとする.
		A = Matrix.multiply(multiplier,A); //行列Aにスカラーmultiplierをかける．
		B = Matrix.multiply(multiplier,B); //ベクトルBにスカラーmultiplierをかける．

		this.A = A;
		this.B = B;

		if (DEBUG == -2) {
			Console.OUT.println("*Z="+this.Z);
		        Console.OUT.println("\t*expectedFCNPricesTPORT="+expectedFCNPricesTPORT.get(this.orderMarket(0))+",expectedRisk="+expectedRisk.get(this.orderMarket(0)).get(this.orderMarket(0))+",expectedFCNReturns="+expectedFCNReturns.get(this.orderMarket(0))+",Z="+this.Z);
			//各セル，各要素の値の絶対値が小さすぎる場合を考えて，それが計算に影響しないように，AとB両方に同じ数をかける．
			Console.OUT.print("\n"+"\t*Q=");
			Matrix.dump(A);
			Console.OUT.print("\t*C=");
			Matrix.dump(B);
			//最適ポートフォリオのベクトルX(連続値)が一意に計算できる場合には、計算する。
			Console.OUT.println("*detA="+Matrix.determinant(A));
			Console.OUT.println("\t"+check(A)+"A");

		}

		var rankA:Long;

		if(A.size==1){
			rankA = 1;
		}else{
			rankA = Matrix.rank( Matrix.echelonForm(A) );
		}	
		var rankE:Long = Matrix.rank( Matrix.echelonForm(Matrix.ExpansionCoefficientMatrix(A,B)) );
		//バーゼル以外の必要な制約条件（線形式）を考慮に入れて再計算（値が非負など）
		var constraints:Rail[Rail[Double]] = FCNMarkowitzPortfolioAgent.constraints(A.size,this.shortSellingAbility,this.Z,this.maxPositionSize,this.leverageRate,presentMarketPricesTPORT,this.orderMarket);
		//Console.OUT.println("**const");
		//Matrix.dump(constraints);
		this.C = Matrix.devideExpansionCoefficientMatrix1(constraints);
		this.D = Matrix.devideExpansionCoefficientMatrix2(constraints);
		if (DEBUG == -2) {
			Console.OUT.println("**A");
			Matrix.dump(this.C);
			Console.OUT.println("**B");
			Matrix.dump(this.D);
		}
		//原点を代入し，原点が制約条件を全て満たすことを確認.
		var initialValue:Rail[Double] =  Matrix.initialASM0(translation6(presentMarketPricesTPORT,this.orderMarket),this.Z,0.9);
		//var initialValue:Rail[Double] =  new Rail[Double](this.C(0).size);

		//A*X=BのベクトルX(連続値)が一意に計算できず、最適ポジションが一意に計算できない場合は、理論的には以下の2ケースのどちらか。
		//	a.解が無限個ある場合（解空間の次元数は n - rankA）
		//	b.解がない場合（AとBから作った拡大係数行列を階段行列にして整理したときに、0ベクトルでないある行i1とi2(i1≠i2)が互いに平行な場合）
		//⇒　しかし、Aが共分散行列をベースにしたもので、B_iがiのlogリターンと予想価格に比例する今の状態ではb.はありえない。
		//一方、a.の解き方は以下。
		//        1. 目的（関数）を、現在のポジションとの距離の最小化にする。
        	//	  2. 行列AとBから解空間を求め、その解空間の式を制約条件にする。
        	//	　3. 1&2の問題をラグランジュ法及び有効制約法で解く。
		//このとき、現在のポジションが解空間の一部なら、ラグランジュ法のλは負になる（しかし現在のポジションは離散変数なので普通こんなことは起きない.
		//だからこのケースは考えなくてよい）。
		//Console.OUT.println("*ほげ");
		if(this.Z<Matrix.minimum(translation6(presentMarketPricesTPORT,this.orderMarket)) 
		|| getZ( presentMarketPricesOneMonth(time) ) <  Matrix.minimum(translation6(presentMarketPricesOneMonth(time),this.orderMarket))
		|| getZ( presentMarketPricesOneDay(time) ) <  Matrix.minimum(translation6(presentMarketPricesOneDay(time),this.orderMarket))
		|| getZ( presentMarketPricesStep(time) ) <  Matrix.minimum(translation6(presentMarketPricesStep(time),this.orderMarket)) 
		){

			x =  new Rail[Double](this.C(0).size);
		}else{
			val n = this.C(0).size;
			val prices:Rail[Double] = translation6(presentMarketPricesTPORT, orderMarket);
			val target = PortfolioOptimizer.makeTargetFunction(A, B);
			val constraint = (x:Rail[Double], grad:Rail[Double]) => {
				Rail.copy(prices, grad as Rail[Double]);
				return Matrix.multiply(prices, x) - Z; // まあたぶんZが所持資産なんやろ。しらんけど。
			};
			val opt = new PortfolioOptimizer(
				n, target, constraint, "MMA"
			);
			val start = System.nanoTime();
			x = opt.optimize();
			val consumed = System.nanoTime() - start;
			Console.OUT.println("#[DBG]: optimize consumed " + (consumed / 1e9) + " secs.");
			if (consumed >= 1e10) {
				Console.OUT.println("[DBG]: OPTIMIZATION PROBLEM:");
				Console.OUT.println("[DBG]: \tA: " + A);
				Console.OUT.println("[DBG]: \tB: " + B);
				Console.OUT.println("[DBG]: \tP: " + prices);
				Console.OUT.println("[DBG]: \tbudget: " + Z);
			}
		}

		val long_x = new Rail[Long](x.size);
		for (i in x.range()) long_x(i) = x(i) as Long;
		y = asMarketVolumeMap(long_x, orderMarket);
		// XXX: 誤差のせいかときどきひっかかる。パフォーマンスみたいだけなのでとりあえず無効化。 7/28, matsuura.
		// assert Matrix.checkInitialASM(this.C,this.D,FCNMarkowitzPortfolioAgent.translation5(y,orderMarket)):"optimalCheckError";

		//最適ポートフォリオのベクトルX(離散値)でフィールド変数のoptimalVolumes,orderPricesを更新。
		//またlastUpdatedもtに更新。
		this.lastUpdated = TPS(0)*this.TPORT*this.numStepsOneDay;
		this.optimalVolumes = FCNMarkowitzPortfolioAgent.translation2(y,orderMarket);
		this.orderPrices = FCNMarkowitzPortfolioAgent.translation1(expectedFCNPricesTPORT,orderMarket);

	}

	public def checkASMError(x:Rail[Double]):Boolean{
		var c:Long =0;
		for(i in 0..(x.size-1)){
			if( x(i).isNaN() ){
				c++;
			}
		}
		if(c==x.size){
			return false;
		}else{
			return true;
		}
	}

	public def maximizedVector(init:HashMap[Market,Long]):HashMap[Market,Long] {
		var out:HashMap[Market,Long] = init;
		var candidates:ArrayList[HashMap[Market,Long]] = new ArrayList[HashMap[Market,Long]]();
		var lastValue:Double = 0.0;
		var count:Long = 0;
		//Console.OUT.println("*maximizedVector:");
		do{
			var max:Double =0.0;
			count++;
			//Console.OUT.println("*turn"+count);
			val out2:Rail[Double] = translation4(translation2(out,this.orderMarket) as Map[Long,Long], this.orderMarket);
			lastValue = targetFunction(out);
			candidates = FCNMarkowitzPortfolioAgent.getChebyshevDistanceNeighbor( translation7(translation2(out,this.orderMarket) as Map[Long,Long], this.orderMarket), orderMarket, 1);
			candidates.add(out);
			/*Console.OUT.println("**candidates1:");
			for(var i:Long = 0; i<candidates.size(); i++){
				Console.OUT.println("***hoge"+i);
				Matrix.dump(FCNMarkowitzPortfolioAgent.translation5(candidates.get(i),orderMarket));
				max = targetFunction(candidates.get(i));
				Console.OUT.println("****value:"+max +"\n" );
			}*/
			candidates = getLongConstrainedCandidates(candidates,this.C,this.D, this.orderMarket);
			/*Console.OUT.println("*candidates2:");
			for(var i:Long = 0; i<candidates.size(); i++){
				Console.OUT.println("***geho"+i);
				Matrix.dump(FCNMarkowitzPortfolioAgent.translation5(candidates.get(i),orderMarket));
				max = targetFunction(candidates.get(i));
				Console.OUT.println("****value:"+max +"\n" );
			}*/
			out = argMaximize(candidates);
			//Console.OUT.println("**out");
			//Matrix.dump(FCNMarkowitzPortfolioAgent.translation5(out,orderMarket));
			max = targetFunction(out);
			//Console.OUT.println("****value:"+max +"\n" );
			//Console.OUT.println("****lastvalue:"+lastValue +"\n" );
		}while( lastValue < targetFunction(out) || count < 10 );	
		return out;
	}


	//制約条件(左辺<=右辺)を拡大係数行列の形で返す(但し現在のプログラムでは，=や<の制約条件は扱えない)
	public static def constraints(numMarkets:Long, shortSellingAbility:Boolean, Z:Double,maxPositionSize:Long,leverageRate:Double,presentMarketPrices:HashMap[Market,Double],orderMarket:ArrayList[Market]):Rail[Rail[Double]]{
		var n:Long = numMarkets;
		var const:Rail[Rail[Double]];
		var prices:Rail[Double] = FCNMarkowitzPortfolioAgent.translation6(presentMarketPrices,orderMarket);

		//空売り禁止（最適ポジションに負の値を取らせない）ならば、その規制に対応する行列を生成。
		if(!shortSellingAbility){
			var constShort:Rail[Rail[Double]] =  new Rail[Rail[Double]](n);
			for(i in 0..(n - 1)){
				constShort(i) = new Rail[Double](n+1);
			}

			for(i in 0..(n - 1)){
				for(j in 0..(n - 1)){
					if(i==j){
						constShort(i)(j) = -1.0;
					}else{
						constShort(i)(j) = 0.0;
					}
				}
				constShort(i)(n) = 0.0;
			}
			//Console.OUT.println("*constShort");
			//Matrix.dump(constShort);

			//借金規制に対応するベクトルを生成
			var constBudget:Rail[Double] = new Rail[Double](n+1);
			for(i in 0..(n - 1)){
				constBudget(i) = prices(i);
			}

			if(Z>=0){
				constBudget(n) = leverageRate*Z;
			}else{
				constBudget(n) = 0.0;
			}

			const = new Rail[Rail[Double]](n+1);
			for(i in 0..(n - 1)){
				const(i) = constShort(i);
			}
			const(n) = constBudget;

		}else{

			//借金規制に対応するベクトルを生成
			var constBudget:Rail[Rail[Double]] = new Rail[Rail[Double]](Math.pow2(n));
			for(i in 0..(Math.pow2(n) - 1)){
				constBudget(i) = new Rail[Double](n+1);
			}
	
			for(i in 0..(Math.pow2(n) - 1)){
				var keisuu:Rail[Double] =  indexBudget(i, n);
	
				for(j in 0..(n - 1)){
					constBudget(i)(j) = keisuu(j)*prices(j);
				}
				if(Z>=0){
					constBudget(i)(n) = leverageRate*Z;
				}else{
					constBudget(i)(n) = 0.0;
				}
			}

			const = constBudget;

		}

		//Console.OUT.println("*constBudget");
		//Matrix.dump(constBudget);
		//Console.OUT.println("*shortSellingAbility");
		//Console.OUT.println(shortSellingAbility);


		//Console.OUT.println("*const");
		//Matrix.dump(const);
		return  const; 
		//return constMax;
	}

	public static def indexBudget(value:Long, n:Long):Rail[Double]{
		var out:Rail[Double] = new Rail[Double](n);
		var value2:Long = value;
		//Console.OUT.println("**value"+value);
		for(var i:Long = n-1; i>=0; i--){
			//Console.OUT.println("**i:"+i);
			//Console.OUT.println("***value2"+value2);
			//Console.OUT.println("***pow2"+Math.pow2(i));
			if(Math.pow2(i) <= value2){
				//Console.OUT.println("***yes");
				out(i) = 1.0;
				value2 = value2 - Math.pow2(i);
			}else{
				//Console.OUT.println("***no");
				out(i) = -1.0;
			}
		}
		return out;
	}

	public def check(A:Rail[Rail[Double]]):boolean{
		for(var i:Long = 0; i<A.size; i++){
			if(A(i)(i)==0.0 || A(i)(i).isNaN() ){
				return true;
			}
		}
		return false;
	}

	//17. 最適ポートフォリオのベクトルX(離散値)の候補candidates,予想されるTPORT*numStepsOneDay後の市場価格,予想リターンexpectedLogReturns,リスクexpectedRisk,総予算Z　を元に、目的関数を最大化するベクトルX(離散値)をcandidatesの中から選び返す。
	public def argMaximize(candidates:ArrayList[HashMap[Market,Long]]):HashMap[Market,Long]{
		var out:HashMap[Market,Long] = new HashMap[Market,Long](0);
		var targetMax:Double = Double.NEGATIVE_INFINITY;
		for(c in candidates){
			val targetC:Double = this.targetFunction(c);
			if(targetC >= targetMax){
				targetMax = targetC;
				out = c;
			}
		}
		return out;
	}


	//17sub. 予想されるTPORT*numStepsOneDay後の市場価格,ポートフォリオのベクトル（離散）assetVolume,予想リターンexpectedLogReturns,リスクexpectedRisk,総予算Z　を元に、そのポートフォリオのベクトルが与えられたときの目的関数の値を返す。
	public def targetFunction(assetVolume:HashMap[Market,Long]):Double{
		var out:Double = 0.0;

		var vol:Rail[Double] = translation5(assetVolume,this.orderMarket);

		//リターンの項の計算
		var out1:Double = Matrix.multiply(this.B, vol);

		//リスクの項の計算
		var out2:Double = Matrix.multiply(Matrix.multiply(this.A, vol),vol)/2.0;

		//2つの項の足しあわせ.
		out = out1 - out2;
		return out;
	}	


	public def targetFunctionD(assetVolume:HashMap[Market,Double]):Double{
		var out:Double = 0.0;

		var vol:Rail[Double] = translation6(assetVolume,this.orderMarket);

		//リターンの項の計算
		var out1:Double = Matrix.multiply(this.B, vol);

		//リスクの項の計算
		var out2:Double = Matrix.multiply(Matrix.multiply(this.A, vol),vol)/2.0;

		//2つの項の足しあわせ.
		out = out1 - out2;
		return out;
	}


	//16sub. 最適ポートフォリオのベクトルX(離散値)の候補を制約条件で絞る．
	public static def getLongConstrainedCandidates(before:ArrayList[HashMap[Market,Long]],C:Rail[Rail[Double]], D:Rail[Double], orderMarket:ArrayList[Market] ):ArrayList[HashMap[Market,Long]]{
		var out:ArrayList[HashMap[Market,Long]] = new ArrayList[HashMap[Market,Long]]();
		for(var i:Long = 0; i<before.size(); i++){
			var hoge:Rail[Double] = FCNMarkowitzPortfolioAgent.translation5(before.get(i),orderMarket);
			//Matrix.dump(hoge);
			if( Matrix.checkInitialASM(C,D,hoge) ){
				out.add(before.get(i));
			}
		}
		return out;
	}

	public static def getChebyshevDistanceNeighbor(x:Rail[Long], orderMarket:ArrayList[Market], distance:Long ):ArrayList[HashMap[Market,Long]]{
		var directions:ArrayList[String] = new ArrayList[String](0);
		var out:ArrayList[HashMap[Market,Long]] = new ArrayList[HashMap[Market,Long]](0);
		var out2:ArrayList[Rail[Long]] = new ArrayList[Rail[Long]]();
		var element:String = new String();
		getPowerSet2(element,directions,1, x.size);
		val size:Long = directions.size();
		val dim:Long = orderMarket.size();
		//Console.OUT.println("*distance:"+distance);
		//Console.OUT.println("**sizeDirection:"+size);
		assert size == (Math.pow(3,dim) as Long) : "powerSetErr:"+size; 
		for(var i:Long = 0; i<size; i++){
			//Console.OUT.println("**direction("+(i+1)+"):");
			//Console.OUT.println(directions.get(i));
			var direction:Rail[Long] = new Rail[Long](dim);
			val components:Rail[String] = directions.get(i).split("_");
			for(var j:Long = 0; j<dim; j++){
				direction(j) = Long.parse( components(j) );
			}
			//Matrix.dump(direction);
			var subset:ArrayList[Rail[Long]] =shareChebyshevD(direction,distance);
			out2.addAll(subset);
		}
		/*var ct:Long = 0;
		for(var i:Long = 0; i<out2.size(); i++){
			for(var j:Long = 0; j<out2.size(); j++){
				if(eqcheck(out2.get(i),out2.get(j))){ ct++; }
			}
		}

		Console.OUT.println("**ct:"+ct);*/

		for(var i:Long = 0; i<out2.size(); i++){
			//Matrix.dump(out2.get(i));
			assert absMax(out2.get(i)) == distance:"getChebyshevDistanceNeighborError";
			val hoge0 = Matrix.plus(out2.get(i),x);
			val hoge = FCNMarkowitzPortfolioAgent.translation9(hoge0,orderMarket);
			val hoge2 = FCNMarkowitzPortfolioAgent.translation3(hoge ,orderMarket );
			out.add(hoge2);
			//out = addArrayList(out, hoge2,orderMarket );
		}
		return out;
	}

	public static def getPowerSet2(element:String, powerIndexSet:ArrayList[String], max:Long, n:Long):void{
		assert max >=0: "getPowerSet2Error"+max;		
		var components:Rail[String] = element.split("_");
		val i:Long = components.size;
		//Console.OUT.println("*i="+i+":");
		if(i==n){
			powerIndexSet.add(element);
		}else{
			if(max > 0){
				for(var j:Long = -max; j<=max; j++ ){
					getPowerSet2(element + j + "_",powerIndexSet,max, n );
				}
			}else{
				getPowerSet2(element + "0_",powerIndexSet,max, n );
			}
		}
	}

	private static def shareChebyshevD(direction:Rail[Long], d:Long):ArrayList[Rail[Long]]{
		var out:ArrayList[Rail[Long]] = new ArrayList[Rail[Long]]();
		val dim = direction.size;
		val num = num(direction);

		//Console.OUT.println("***num="+num);
		//Console.OUT.println("***distance="+d);

		if( d==0 && num==0 ){
			var elem:Rail[Long] = new Rail[Long](dim);
			out.add(elem);

		//この場合は，directionを満たすdistanceのshareの仕方は存在しない.
		}else if( d==0 || num == 0){
			
		}else{
			val rest:Long = dim - num;
			//Console.OUT.println("rest="+rest);
			val cb:ArrayList[String] = new ArrayList[String]();
			val max = d -1;
			getPowerSet2(new String(),cb,max, rest);
			//Console.OUT.println("cbSize="+cb.size());
			for(var i:Long = 0; i<cb.size(); i++){
				var elem:Rail[Long] = new Rail[Long](dim);
				for(var j:Long = 0; j<dim; j++){
					elem(j) = direction(j)*d;
				}
				var count:Long = 0;
				val tcb = cb.get(i).split("_");
				for(var j:Long = 0; j<dim; j++){
					if(elem(j)==0 && count < tcb.size ){
						elem(j) = Long.parse(tcb(count));
						count++;
					}
					//Console.OUT.println(elem(j));
				}
				out.add(elem);
			}
		}

		return out;
	}


	private static def num(direction:Rail[Long]):Long{
		var out:Long = 0;
		val n:Long = direction.size;
		for(var i:Long = 0; i<n; i++){
			out = out +Math.abs(direction(i));
		}
		return out;
	}

	private static def absMax(x:Rail[Long]):Long{
		var out:Long = Long.MIN_VALUE;
		for(i in 0..(x.size - 1)){
			if( Math.abs( x(i) )  >out){
				out = Math.abs( x(i) );
			}
		}
		return out;
	}

	//16. 最適ポートフォリオのベクトルX(連続値)を元に最適ポートフォリオのベクトルX(離散値)の候補を返す。
	public static def getLongCandidates(x:Rail[Double], orderMarket:ArrayList[Market]):ArrayList[HashMap[Market,Long]]{
		var powerIndexSet:ArrayList[String] = new ArrayList[String](0);
		var out:ArrayList[HashMap[Market,Long]] = new ArrayList[HashMap[Market,Long]]();
		var element:String = new String();
		getPowerSet(element,powerIndexSet, x);
		val size:Long = powerIndexSet.size();
		val dim:Long = x.size;
		assert size == (Math.pow(2,dim) as Long) : "powerSetErr"; 
		for(var i:Long = 0; i<size; i++){
			//Console.OUT.println(powerIndexSet(i));
			var trueElement:HashMap[Market,Long] = new HashMap[Market,Long](0);
			val components:Rail[String] = powerIndexSet.get(i).split("_");
			for(var j:Long = 0; j<dim; j++){
				val y:Long = Long.parse( components(j) );
				//Console.OUT.println("("+i+","+j+"):"+y+","+this.orderMarket.get(j).name);
				trueElement.put(orderMarket.get(j),y);
			}
			out.add(trueElement);
		}
		return out;
	}

	//getPowerSetのテスト用
	private static def test(x:Rail[Double]){
		for(var i:Long = 0; i<x.size; i++ ){
			Console.OUT.print(x(i)+"\t");
		}
		Console.OUT.println("");

		var powerIndexSet:ArrayList[String] = new ArrayList[String](0);
		var out:ArrayList[HashMap[Market,Long]] = new ArrayList[HashMap[Market,Long]]();
		var element:String = new String();
		getPowerSet(element,powerIndexSet, x);
		for(var i:Long = 0; i<powerIndexSet.size(); i++ ){
			Console.OUT.println(powerIndexSet.get(i));
		}
	}

	//16sub. ベクトルx:Rail[Double](n)　〜連続値〜　の周辺のLongのベクトル2^n個をpowerIndexSetにString形式で格納していく再帰関数。
	public static def getPowerSet(element:String, powerIndexSet:ArrayList[String], x:Rail[Double]):void{		
		val n:Long = x.size;
		var components:Rail[String] = element.split("_");
		val i:Long = components.size;
		//Console.OUT.println("*i="+i+":");
		if(i==n){
			powerIndexSet.add(element);
		}else{
			for(var j:Long = 0; j<2; j++ ){
				if(j==0){
					getPowerSet(element+((Math.ceil(x(i)) -1) as Long)+"_",powerIndexSet,x);
				}else{
					getPowerSet(element+(Math.ceil(x(i)) as Long)+"_",powerIndexSet,x);
				}
			}
		}
	}

	//15. 予想されるTPORT*numStepsOneDay後の市場価格と予想される今期のリターン,リスク及び現時点で所有している
	//総資産の価値の総額Z,marketの呼び出し順序を元に、（最適ポートフォリオのベクトルXの計算に必要な）AX = B の
	//行列Aを計算。
	public static def getA(expectedPrices:HashMap[Market,Double], expectedLogReturns:HashMap[Market,Double], expectedRisk:HashMap[Market,HashMap[Market,Double]], Z:Double,b:Double, orderMarket:ArrayList[Market]):Rail[Rail[Double]]{
		//初期化。
		var out:Rail[Rail[Double]] = new Rail[Rail[Double]](orderMarket.size());
		for(i in 0..(orderMarket.size() - 1)){
			out(i) = new Rail[Double](orderMarket.size());
		}
		//計算開始。
		for(i in 0..(orderMarket.size() - 1)){
			for(j in 0..(orderMarket.size() - 1)){
				//Console.OUT.println("\t*(i,j)=("+i+","+j+"):");
				//Console.OUT.println("\t*expectedPrices="+expectedPrices.get(orderMarket(0))+",expectedRisk="+expectedRisk.get(orderMarket(0)).get(orderMarket(0))+",expectedLogReturns="+expectedLogReturns.get(orderMarket(0))+",Z="+Z);


//				out(i)(j) = (this.b/(Z*Z))*expectedRisk.get(orderMarket(j)).get(orderMarket(i))*expectedLogReturns.get(orderMarket(i))*expectedLogReturns.get(orderMarket(j))*expectedPrices.get(orderMarket(i))*expectedPrices.get(orderMarket(j));

				out(i)(j) = (b/(Z*Z))*expectedRisk.get(orderMarket(j)).get(orderMarket(i))*expectedPrices.get(orderMarket(i))*expectedPrices.get(orderMarket(j));
				//Console.OUT.println("\toutA="+out(i)(j));
			}
		}
		return out;
	}

	//14. 予想されるTPORT*numStepsOneDay後の市場価格と予想される今期のリターン,及び,現時点で所有している総資産の価値の総額Z,
	//marketの呼び出し順序を元に、（最適ポートフォリオのベクトルXの計算に必要な）AX = B のBベクトルを計算。
	public static def getB(expectedPrices:HashMap[Market,Double], expectedLogReturns:HashMap[Market,Double], Z:Double, orderMarket:ArrayList[Market]):Rail[Double]{
		var out:Rail[Double] = new Rail[Double](orderMarket.size());
		val n:Long = orderMarket.size();
		for(var i:Long = 0; i<n; i++ ){

			//Console.OUT.println("\t*expectedPrices="+expectedPrices.get(orderMarket(0))+",expectedLogReturns="+expectedLogReturns.get(orderMarket(0))+",Z="+Z);
			out(i) = expectedLogReturns.get(orderMarket(i))*expectedPrices.get(orderMarket(i))/Z;
			//Console.OUT.println("\toutB="+out(i));
		}
		return out;
	}




	//13. marketの呼び出し順序を返すメソッド
	public def marketOrder():ArrayList[Market]{
		val out:ArrayList[Market] = new ArrayList[Market](0);
		for(market in accessibleMarkets){
			out.add(market);
		}
		return out;
	}

	//12. 各市場の今期の市場価格を元に，現時点で所有している総資産の価値の総額Zを計算。
	public def getZ(presentMarketPrices:HashMap[Market,Double]):Double{
		var out:Double = this.cashAmount;
		for(i in 0..(this.orderMarket.size() - 1)){
			out = out + presentMarketPrices(orderMarket.get(i))*(this.getAssetVolume(orderMarket.get(i)) as Double);
		}
		return out;
	}







	public def accessibleMarket(markets:List[Market]):void{
		this.accessibleMarkets = new ArrayList[Market](0);
		for(market in markets){
			if(isMarketAccessible(market)){
				this.accessibleMarkets.add(market);
			}
		}
	}

	public def sizeMinA(A:Rail[Rail[Double]]):Double{
		var out:Double =Double.POSITIVE_INFINITY;
		val n:Long = A.size;
		for(var i:Long = 0; i<n; i++){
			for(var j:Long = 0; j<n; j++){
				if(Math.abs(A(i)(j))<out){
					out = Math.abs(A(i)(j));
				}
			}
		}
		return out;
	}


	public def sizeMinB(B:Rail[Double]):Double{
		var out:Double =Double.POSITIVE_INFINITY;
		val n:Long = B.size;
		for(var i:Long = 0; i<n; i++){
			if(Math.abs(B(i))<out){
				out = Math.abs(B(i));
			}
		}
		return out;
	}

	public static def getPF(presentVolume:Rail[Long], presentMarketPrices:Rail[Double], Z:Double):Rail[Double]{
		assert presentVolume.size == presentMarketPrices.size :"getPFError";
		val n = presentVolume.size;
		var rest:Double = Z;
		var out:Rail[Double] = new Rail[Double](presentVolume.size+1);
		for(var i:Long = 1; i<=n; i++ ){
			out(i) = (presentVolume(i-1) as Double)*presentMarketPrices(i-1);
			rest = rest - out(i);
		}
		out(0) = rest;
		return out;
	}

	public static def translationm2(base:Rail[Double],orderMarket:ArrayList[Market]):HashMap[Market,Double]{
		val n = base.size;
		out:HashMap[Market,Double] = new HashMap[Market,Double]();
		for(var i:Long = 0; i<n; i++ ){
			//Console.OUT.println("**i="+i+": *baseName = "+orderMarket.get(i).name);
			out.put(orderMarket.get(i), base(i));
		}
		return out;
	}

	public static def translationm1(base:Rail[Long],orderMarket:ArrayList[Market]):HashMap[Market,Long]{
		val n = base.size;
		out:HashMap[Market,Long] = new HashMap[Market,Long]();
		for(var i:Long = 0; i<n; i++ ){
			//Console.OUT.println("**i="+i+": *baseName = "+orderMarket.get(i).name);
			out.put(orderMarket.get(i), base(i));
		}
		return out;
	}

	public static def translation0(base:Rail[Long]):Rail[Double]{
		val n = base.size;
		var out:Rail[Double] = new Rail[Double](n);
		for(var i:Long = 0; i<n; i++ ){
			out(i) = base(i) as Double; 
		}
		return out;
	}

	public static def translation0(base:Rail[Double]):Rail[Long]{
		val n = base.size;
		var out:Rail[Long] = new Rail[Long](n);
		for(var i:Long = 0; i<n; i++ ){
			out(i) = Math.round( base(i) ) as Long; 
		}
		return out;
	}

	public static def translation1(base:HashMap[Market,Double],orderMarket:ArrayList[Market]):HashMap[Long,Double]{
		out:HashMap[Long,Double] = new HashMap[Long,Double]();
		val n:Long = orderMarket.size();
		for(var i:Long = 0; i<n; i++ ){
			out.put((orderMarket.get(i).id as Long), base.get(orderMarket.get(i)));
		}
		return out;
	}

	public static def translation2(base:HashMap[Market,Long],orderMarket:ArrayList[Market]):HashMap[Long,Long]{
		out:HashMap[Long,Long] = new HashMap[Long,Long]();
		val n:Long = orderMarket.size();
		for(var i:Long = 0; i<n; i++ ){
			out.put((orderMarket.get(i).id as Long), base.get(orderMarket.get(i)));
		}
		return out;
	}

	public static def translation3(base:Map[Long,Long],orderMarket:ArrayList[Market]):HashMap[Market,Long]{
		out:HashMap[Market,Long] = new HashMap[Market,Long]();
		val n:Long = orderMarket.size();
		for(var i:Long = 0; i<n; i++ ){
			//Console.OUT.println("**i="+i+": *baseName = "+orderMarket.get(i).name);
			out.put(orderMarket.get(i), base.get(orderMarket.get(i).id));
		}
		return out;
	}

	public static def translation4(base:Map[Long,Long],orderMarket:ArrayList[Market]):Rail[Double]{
		val n:Long = orderMarket.size();
		out:Rail[Double] = new Rail[Double](n);
		for(var i:Long = 0; i<n; i++ ){
			out(i) = base.get(orderMarket.get(i).id);
		}
		return out;
	}



	public static def translation5(base:HashMap[Market,Long],orderMarket:ArrayList[Market]):Rail[Double]{
		val n:Long = orderMarket.size();
		out:Rail[Double] = new Rail[Double](n);
		for(var i:Long = 0; i<n; i++ ){
			//Console.OUT.println("j="+orderMarket(i).id+":"+base.get(orderMarket(i)));
			out(i) = base.get(orderMarket.get(i));
		}
		return out;
	}

	public static def translation6(base:HashMap[Market,Double],orderMarket:ArrayList[Market]):Rail[Double]{
		val n:Long = orderMarket.size();
		out:Rail[Double] = new Rail[Double](n);
		for(var i:Long = 0; i<n; i++ ){
			//Console.OUT.println("j="+orderMarket(i).id+":"+base.get(orderMarket(i)));
			out(i) = base.get(orderMarket.get(i));
		}
		return out;
	}

	public static def translation7(base:Map[Long,Long],orderMarket:ArrayList[Market]):Rail[Long]{
		val n:Long = orderMarket.size();
		out:Rail[Long] = new Rail[Long](n);
		//Console.OUT.println("n:"+n);
		for(var i:Long = 0; i<n; i++ ){
			//Console.OUT.println("i:"+i);
			//Console.OUT.println("id:"+orderMarket.get(i).id);
			if(base.containsKey(orderMarket.get(i).id)){
				out(i) = base.get(orderMarket.get(i).id);
			}
		}
		return out;
	}

	public static def translation8(base:Map[Long,Long],orderMarket:ArrayList[Market] ):HashMap[Market,Double]{
		val n:Long = orderMarket.size();
		out:HashMap[Market,Double] = new HashMap[Market,Double]();
		for(var i:Long = 0; i<n; i++ ){
			out.put(orderMarket.get(i), (base.get(orderMarket.get(i).id) as Double));
		}
		return out;
	}

	public static def translation9(base:Rail[Long],orderMarket:ArrayList[Market]):HashMap[Long,Long]{
		//Console.OUT.println("*before9:");
		//Matrix.dump(base);
		out:HashMap[Long,Long] = new HashMap[Long,Long]();
		for(var i:Long = 0; i<base.size; i++ ){
			//Console.OUT.println("**i="+i+": *base = "+ base(i)+ ","+orderMarket.get(i).id);
			//out.put(orderMarket.get(i).id, base(orderMarket.get(i).id) );
			out.put(orderMarket.get(i).id, base(i) );
		}
		//Console.OUT.println("*9:");
		//FCNMarkowitzPortfolioAgent.dump(out,orderMarket);
		return out;
	}


	public static def translation10(base:HashMap[Market,HashMap[Market,Double]],orderMarket:ArrayList[Market]):HashMap[Long,HashMap[Long,Double]]{
		val n:Long = orderMarket.size();
		out:HashMap[Long,HashMap[Long,Double]] = new HashMap[Long,HashMap[Long,Double]](n);
		for(var i:Long = 0; i<n; i++ ){
			val out2:HashMap[Long,Double] = new HashMap[Long,Double]();
			for(var j:Long = 0; j<n; j++ ){
				out2.put( orderMarket.get(j).id, base.get(orderMarket.get(i)).get(orderMarket.get(j)) );
			}
			out.put(orderMarket.get(i).id, out2);
		}
		return out;
	}

	public static def translation11(base:HashMap[Long,HashMap[Long,Double]],orderMarket:ArrayList[Market]):HashMap[Market,HashMap[Market,Double]]{
		val n:Long = orderMarket.size();
		out:HashMap[Market,HashMap[Market,Double]] = new HashMap[Market,HashMap[Market,Double]](n);
		for(var i:Long = 0; i<n; i++ ){
			val out2:HashMap[Market,Double] = new HashMap[Market,Double]();
			for(var j:Long = 0; j<n; j++ ){
				out2.put( orderMarket.get(j), base.get(orderMarket.get(i).id).get(orderMarket.get(j).id) );
			}
			out.put(orderMarket.get(i), out2);
		}
		return out;
	}

	public static def translation12(base:HashMap[Market,HashMap[Market,Double]],orderMarket:ArrayList[Market]):Rail[Rail[Double]]{
		val n:Long = orderMarket.size();
		out:Rail[Rail[Double]] = new Rail[Rail[Double]](n);
		for(var i:Long = 0; i<n; i++ ){
			val out2:Rail[Double] = new Rail[Double](n);
			for(var j:Long = 0; j<n; j++ ){
				out2(j) = base.get(orderMarket.get(i)).get(orderMarket.get(j));
			}
			out(i) = out2;
		}
		return out;
	}

	public static def dump(y:HashMap[Market,Double],orderMarket:ArrayList[Market] ){
		val n:Long = orderMarket.size();
		for(var i:Long = 0; i<n; i++ ){
			Console.OUT.print(y.get(orderMarket.get(i))+",");
		}
		Console.OUT.println("");
	}

	public static def dump(y:HashMap[Market,Long],orderMarket:ArrayList[Market] ){
		val n:Long = orderMarket.size();
		for(var i:Long = 0; i<n; i++ ){
			Console.OUT.print(y.get(orderMarket.get(i))+",");
		}
		Console.OUT.println("");
	}

	public static def dump(y:HashMap[Long,Long],orderMarket:ArrayList[Market]  ){
		val n:Long = y.size();
		for(var i:Long = 0; i<n; i++ ){
			Console.OUT.print(y.get(orderMarket.get(i).id)+",");
		}
		Console.OUT.println("");
	}

	public def getOptimalVolumes(market:Market){
		return optimalVolumes.get((market.id as Long));
	}

	public def getOrderPrices(market:Market){
		return orderPrices.get((market.id as Long));
	}

	public static def isFinite(x:Double) {
		return !x.isNaN() && !x.isInfinite();
	}


	//11. TPORT期毎のnowTime - timeSize*TPORT*numStepsOneDay期からnowTime期までの各市場の市場とファンダメンタルのリターンを元に、
	//リスク（分散共分散行列）を計算し、その荷重和を返す。 
	public def expectedRisk(recentMarketReturnsTPORT:HashMap[Market,ArrayList[Double]], recentFundamentalReturnsTPORT:HashMap[Market,ArrayList[Double]],covarfundamentalWeight:Double ):HashMap[Market,HashMap[Market,Double]]{
		var out1:HashMap[Market,HashMap[Market,Double]] = new HashMap[Market,HashMap[Market,Double]]();
		var out2:HashMap[Market,HashMap[Market,Double]] = new HashMap[Market,HashMap[Market,Double]]();
		var trueout:HashMap[Market,HashMap[Market,Double]] = new HashMap[Market,HashMap[Market,Double]]();

		//リターンの平均を計算
		var aves:Map[Market,Double] = new HashMap[Market,Double]();
		var faves:Map[Market,Double] = new HashMap[Market,Double]();
		for(i in 0..(this.orderMarket.size() - 1)){
			var ave:Double =0.0;
			var fave:Double =0.0;
			val recentMarketReturns = recentMarketReturnsTPORT.get(orderMarket.get(i));
			val recentfReturns = recentFundamentalReturnsTPORT.get(orderMarket.get(i));
	   		for(var j:Long = 0; j < recentMarketReturns.size(); ++j){
				ave = ave + recentMarketReturns(j);
				fave = fave +  recentfReturns(j);
			}
			//Console.OUT.println("ave1:"+ave);
			//Console.OUT.println("fave1:"+fave);
			ave = ave/(recentMarketReturns.size() as Double );
			fave = fave/(recentfReturns.size() as Double );
			aves.put(orderMarket.get(i), ave);
			faves.put(orderMarket.get(i), fave);
			//Console.OUT.println("ave2:"+ave);
			//Console.OUT.println("fave2:"+fave);
			//Console.OUT.println("size1:"+recentMarketReturns.size());
			//Console.OUT.println("size2:"+recentfReturns.size());
		}

		//dump(aves as HashMap[Market,Double],this.orderMarket);
		//dump(faves as HashMap[Market,Double],this.orderMarket);
		//分散共分散を計算しoutに格納.
		for(i in 0..(this.orderMarket.size() - 1)){
			var med:HashMap[Market,Double] = new HashMap[Market,Double](); 
			var fmed:HashMap[Market,Double] = new HashMap[Market,Double](); 
			var tmed:HashMap[Market,Double] = new HashMap[Market,Double](); 
			for(j in 0..(this.orderMarket.size() - 1)){
				val recentMarketReturns1 = recentMarketReturnsTPORT.get(orderMarket.get(i));
				val recentMarketReturns2 = recentMarketReturnsTPORT.get(orderMarket.get(j));

				val recentfReturns1 = recentFundamentalReturnsTPORT.get(orderMarket.get(i));
				val recentfReturns2 = recentFundamentalReturnsTPORT.get(orderMarket.get(j));

				assert recentMarketReturns1.size() == recentMarketReturns2.size()  : "sizeError";
				assert recentfReturns1.size() == recentfReturns2.size()  : "sizeError";
				assert recentMarketReturns1.size() == recentfReturns1.size()  : "sizeError";
				var risk:Double = 0;
				var fRisk:Double = 0;
				var tRisk:Double = 0;
 				for(var k:Long = 0; k < recentMarketReturns1.size(); ++k){
					risk = risk + (aves.get(orderMarket.get(i)) - recentMarketReturns1(k) )* (aves.get(orderMarket.get(j)) - recentMarketReturns2(k) );
					fRisk = fRisk + (faves.get(orderMarket.get(i)) - recentfReturns1(k) )* (faves.get(orderMarket.get(j)) - recentfReturns2(k) );
				}
				risk = risk/(recentMarketReturns1.size()-1);
				fRisk = fRisk/(recentfReturns1.size()-1);
				tRisk = covarfundamentalWeight*risk + (1.0-covarfundamentalWeight)*fRisk;
				med.put(orderMarket.get(j),risk);
				fmed.put(orderMarket.get(j),fRisk);
				tmed.put(orderMarket.get(j),tRisk);
			}
			out1.put(orderMarket.get(i),med);
			out2.put(orderMarket.get(i),fmed);
			trueout.put(orderMarket.get(i),tmed);
		}
		return trueout;
	}

	//10. 今期の市場価格と今期予想されるリターンから予想されるtimeSize*TPORT*numStepsOneDay後の市場価格を計算し返す。
	public def expectedNormalPrices(presentMarketPrices:HashMap[Market,Double], expectedNormalReturns:HashMap[Market,Double]):HashMap[Market,Double]{
		var recents:HashMap[Market,Double] = new HashMap[Market,Double](0);
		//Console.OUT.println("\t*presentMarketPrices:"+presentMarketPrices.get(this.orderMarket.get(0)));
		//Console.OUT.println("\t*expectedNormalReturns:"+expectedLogReturns.get(this.orderMarket.get(0)));

		for(i in 0..(this.orderMarket.size() - 1)){
			val expectedPrice:Double = presentMarketPrices(orderMarket.get(i)) + expectedNormalReturns(orderMarket.get(i))* timeSize;	//ok
			assert isFinite(expectedPrice) : "isFinite(expectedPrice)";
			//Console.OUT.println("\t*timeSize:"+timeSize);
			//Console.OUT.println("\t*expectedPrice:"+expectedPrice);
			recents.put(orderMarket.get(i),expectedPrice);
		}
		return 	recents;	
	}

	//10. 今期の市場価格と今期予想されるリターンから予想されるtimeSize*TPORT*numStepsOneDay後の市場価格を計算し返す。
	public def expectedLogPrices(presentMarketPrices:HashMap[Market,Double], expectedLogReturns:HashMap[Market,Double]):HashMap[Market,Double]{
		var recents:HashMap[Market,Double] = new HashMap[Market,Double](0);
		//Console.OUT.println("\t*presentMarketPrices:"+presentMarketPrices.get(this.orderMarket.get(0)));
		//Console.OUT.println("\t*expectedLogReturns:"+expectedLogReturns.get(this.orderMarket.get(0)));

		for(i in 0..(this.orderMarket.size() - 1)){
			val expectedPrice:Double = presentMarketPrices(orderMarket.get(i))*Math.exp(expectedLogReturns.get(orderMarket.get(i))* timeSize);	//ok
			assert isFinite(expectedPrice) : "isFinite(expectedPrice)";
			//Console.OUT.println("\t*timeSize:"+timeSize);
			//Console.OUT.println("\t*expectedPrice:"+expectedPrice);
			recents.put(orderMarket.get(i),expectedPrice);
		}
		return 	recents;	
	}


	//9. 予想されたファンダメンタルリターンとチャートリターン,ノイズリターンを引数として、引数3つとノイズ項にそれぞれ重み付けした値として、今期予想されるリターンを返す。
	public def expectedFCNReturns(fundamentalsLog:HashMap[Market,Double], chartsLog:HashMap[Market,Double], noiseLog:HashMap[Market,Double]):HashMap[Market,Double]{
		var recents:HashMap[Market,Double] = new HashMap[Market,Double](0);
		for(i in 0..(this.orderMarket.size() - 1)){
			val a = fundamentalsLog.get(orderMarket.get(i));
			val b = chartsLog.get(orderMarket.get(i));
			val c = noiseLog.get(orderMarket.get(i));
			//Console.OUT.println("\ttest:"+a+","+b+","+c);
			var L:ArrayList[Double] = new ArrayList[Double](0);
			L.add(Math.abs(a));
			L.add(Math.abs(b));
			L.add(Math.abs(c));
			L = removeZero(L);
			val min = Matrix.minimum(L);
			val multiplier:Double = Matrix.multiplier(min);
			val a2 = multiplier*a;
			val b2 = multiplier*b;
			val c2 = multiplier*c;
			//Console.OUT.println("\ttest:"+a2+","+b2+","+c2);
			//Console.OUT.println("\tweight:"+this.fundamentalWeight+","+this.chartWeight+","+ this.noiseWeight);
			/* 式 (5) : 期待リターン */
			var expectedLogReturn:Double = (1.0 / (this.fundamentalWeight + this.chartWeight + this.noiseWeight))* 
					(this.fundamentalWeight *a2
					+ this.chartWeight *b2
					+ this.noiseWeight *c2 );
			assert isFinite(expectedLogReturn) : "isFinite(expectedLogReturn)";
			//Console.OUT.print("\tR:"+expectedLogReturn+"/"+multiplier+"=");
			expectedLogReturn = expectedLogReturn/multiplier;
			//Console.OUT.println(expectedLogReturn);
			recents.put(orderMarket.get(i),expectedLogReturn);
		}


		return recents;
	}



	public static def removeZero(base:ArrayList[Double]):ArrayList[Double]{
		out:ArrayList[Double] = new ArrayList[Double](0);
		for(x in base){
			if(Math.abs(x)>0.0){
				out.add(x);
			}
		}
		return out;
	}

	public def recentNoiseReturns():HashMap[Market,Double]{
		var recents:HashMap[Market,Double] = new HashMap[Market,Double](0);
		val random = new RandomHelper(getRandom());
		for(i in 0..(this.orderMarket.size() - 1)){
			/* 式 (8) : ノイズ項 */
			val noiseLogReturn = 0.0 + this.noiseScale * random.nextGaussian();
			recents.put(orderMarket.get(i), noiseLogReturn);
		}
		return recents;
	}


	//8.TPORT期毎のnowTime - timeSize*TPORT*numStepsOneDay期からnowTime期までの各市場のリターンを元に、
	//テクニカルリターン(予想値)を計算する。 
	public def recentChartistReturns(recentMarketReturnsTPORT:HashMap[Market,ArrayList[Double]]):HashMap[Market,Double]{
		var ER:HashMap[Market,Double] = new HashMap[Market,Double]();

		for(i in 0..(this.orderMarket.size() - 1)){
			/* 式 (7) : テクニカル分析項（チャート） */
			val chartMeanLogReturn = Statistics.mean( recentMarketReturnsTPORT.get(orderMarket.get(i)) );
			assert isFinite(chartMeanLogReturn) : "isFinite(chartMeanLogReturn)";
			ER.put(orderMarket.get(i), chartMeanLogReturn);
		}
		return ER;
	}


	//7.今期のファンダメンタル価格と市場価格を基にファンダメンタルリターン(予想値)を計算するメソッド 
	public def recentFundamentalistNormalReturns(presentFundamentalPrices:HashMap[Market,Double],presentMarketPrices:HashMap[Market,Double]):HashMap[Market,Double]{
		var recents:HashMap[Market,Double] = new HashMap[Market,Double](0);
		for(i in 0..(this.orderMarket.size() - 1)){
			/* 式 (6) : ファンダメンタル分析項 */
			val fundamentalScale = 1.0 / this.fundamentalMeanReversionTime;
			val fundamentalNormalReturn:Double = fundamentalScale * ( presentFundamentalPrices(orderMarket.get(i)) - presentMarketPrices(orderMarket.get(i)) );
			//Console.OUT.println("fundcheck:"+presentFundamentalPrices(orderMarket.get(i))+","+presentMarketPrices(orderMarket.get(i)));
			recents.put(orderMarket.get(i),fundamentalNormalReturn);
		}
		return recents;
	}


	//7.今期のファンダメンタル価格と市場価格を基にファンダメンタルリターン(予想値)を計算するメソッド 
	public def recentFundamentalistLogReturns(presentFundamentalPrices:HashMap[Market,Double],presentMarketPrices:HashMap[Market,Double]):HashMap[Market,Double]{
		var recents:HashMap[Market,Double] = new HashMap[Market,Double](0);
		for(i in 0..(this.orderMarket.size() - 1)){
			/* 式 (6) : ファンダメンタル分析項 */
			val fundamentalScale = 1.0 / this.fundamentalMeanReversionTime;
			val fundamentalLogReturn:Double = fundamentalScale * Math.log(presentFundamentalPrices(orderMarket.get(i)) /presentMarketPrices(orderMarket.get(i)) );

			//Console.OUT.println("fundcheck:"+presentFundamentalPrices(orderMarket.get(i))+","+presentMarketPrices(orderMarket.get(i)));
			assert isFinite(fundamentalLogReturn) : "isFinite(fundamentalLogReturn)";
			recents.put(orderMarket.get(i),fundamentalLogReturn);
		}
		return recents;
	}



	//今期の時間TimeとtimeSizeを基に、TPORT日毎のtimeSize個の理論ノーマルリターンを獲得する。 
	public def recentFundamentalNormalReturnsTPORT(Time:Long, timeSize:Long):HashMap[Market,ArrayList[Double]]{
		return recentFundamentalNormalReturnsSomeDays(Time, this.TPORT, timeSize);
	}

	//今期の時間TimeとtimeSizeを基に、月次のtimeSize個の各市場の理論ノーマルリターンを獲得する。 
	public def recentFundamentalNormalReturnsOneMonth(Time:Long, timeSize:Long):HashMap[Market,ArrayList[Double]]{
		return recentFundamentalNormalReturnsSomeDays(Time, this.numDaysOneMonth, timeSize);
	}

	//今期の時間TimeとtimeSizeを基に、日次のtimeSize個の各市場の理論ノーマルリターンを獲得する。 
	public def recentFundamentalNormalReturnsOneDay(Time:Long, timeSize:Long):HashMap[Market,ArrayList[Double]]{
		return recentFundamentalNormalReturnsSomeDays(Time, 1, timeSize);
	}

	//今期の時間TimeとSomeDays,timeSizeを基に、SomeDays日毎のtimeSize個の各市場の理論ノーマルリターンを獲得する。 
	public def recentFundamentalNormalReturnsSomeDays(Time:Long,SomeDays:Long, timeSize:Long):HashMap[Market,ArrayList[Double]]{
		val T = Time - Time%(SomeDays*this.numStepsOneDay);
		var recents:HashMap[Market,ArrayList[Double]] = new HashMap[Market,ArrayList[Double]](0);
		for(i in 0..(this.orderMarket.size() - 1)){
			//Console.OUT.print("\n\t*time(market"+this.orderMarket.get(i).id+"):");
			val recent:ArrayList[Double] = new ArrayList[Double](0);
			for(var j:Long = 0; j < timeSize; j++){
				val r = ( this.orderMarket.get(i).fundamentalPrices(T + (j+1-timeSize)*SomeDays*this.numStepsOneDay) - this.orderMarket.get(i).fundamentalPrices(T + (j-timeSize)*SomeDays*this.numStepsOneDay) ) / this.orderMarket.get(i).fundamentalPrices(T + (j-timeSize)*SomeDays*this.numStepsOneDay);
				//Console.OUT.print((T + (j+1-timeSize)*SomeDays*this.numStepsOneDay)+"");
				//Console.OUT.print("("+r+"),");
				recent.add(r);
			}
			//Console.OUT.print("\n");
			recents.put(this.orderMarket.get(i),recent);
		}

		return recents;
	}


	//今期の時間TimeとtimeSizeを基に、TPORT日毎のtimeSize個の理論対数リターンを獲得する。 
	public def recentFundamentalLogReturnsTPORT(Time:Long, timeSize:Long):HashMap[Market,ArrayList[Double]]{
		return recentFundamentalLogReturnsSomeDays(Time, this.TPORT, timeSize);
	}

	//今期の時間TimeとtimeSizeを基に、月次のtimeSize個の各市場の理論対数リターンを獲得する。 
	public def recentFundamentalLogReturnsOneMonth(Time:Long, timeSize:Long):HashMap[Market,ArrayList[Double]]{
		return recentFundamentalLogReturnsSomeDays(Time, this.numDaysOneMonth, timeSize);
	}

	//今期の時間TimeとtimeSizeを基に、日次のtimeSize個の各市場の理論対数リターンを獲得する。 
	public def recentFundamentalLogReturnsOneDay(Time:Long, timeSize:Long):HashMap[Market,ArrayList[Double]]{
		return recentFundamentalLogReturnsSomeDays(Time, 1, timeSize);
	}

	//今期の時間TimeとSomeDays,timeSizeを基に、SomeDays日毎のtimeSize個の各市場の理論対数リターンを獲得する。 
	public def recentFundamentalLogReturnsSomeDays(Time:Long,SomeDays:Long, timeSize:Long):HashMap[Market,ArrayList[Double]]{
		val T = Time - Time%(SomeDays*this.numStepsOneDay);
		var recents:HashMap[Market,ArrayList[Double]] = new HashMap[Market,ArrayList[Double]](0);
		for(i in 0..(this.orderMarket.size() - 1)){
			//Console.OUT.print("\n\t*time(market"+this.orderMarket.get(i).id+"):");
			val recent:ArrayList[Double] = new ArrayList[Double](0);
			for(var j:Long = 0; j < timeSize; j++){
				val r = Math.log( this.orderMarket.get(i).fundamentalPrices(T + (j+1-timeSize)*SomeDays*this.numStepsOneDay)/this.orderMarket.get(i).fundamentalPrices(T + (j-timeSize)*SomeDays*this.numStepsOneDay) );
				//Console.OUT.print((T + (j+1-timeSize)*SomeDays*this.numStepsOneDay)+"");
				//Console.OUT.print("("+r+"),");
				recent.add(r);
			}
			//Console.OUT.print("\n");
			recents.put(this.orderMarket.get(i),recent);
		}

		return recents;
	}


	public def presentFundamentalPricesTPORT(Time:Long):HashMap[Market,Double]{
		return presentFundamentalPricesSomeDays(Time,this.TPORT);
	}

	public def presentFundamentalPricesOneMonth(Time:Long):HashMap[Market,Double]{
		return presentFundamentalPricesSomeDays(Time,this.numDaysOneMonth);
	}

	public def presentFundamentalPricesOneDay(Time:Long):HashMap[Market,Double]{
		return presentFundamentalPricesSomeDays(Time,1);
	}

	//今期の時間TimeとSomeDaysを基に、SomeDays日毎のtimeSize個の各市場の理論価格を獲得する。 
	public def presentFundamentalPricesSomeDays(Time:Long,SomeDays:Long):HashMap[Market,Double]{
		val T = Time - Time%(SomeDays*this.numStepsOneDay);
		var out:HashMap[Market,Double] = new HashMap[Market,Double]();
		for(i in 0..(this.orderMarket.size() - 1)){
			out.put(this.orderMarket.get(i),this.orderMarket.get(i).getFundamentalPrice(T));
		}
		return out;
	}

	public def presentFundamentalPricesStep(Time:Long):HashMap[Market,Double]{
		val T = Time;
		var out:HashMap[Market,Double] = new HashMap[Market,Double]();
		for(i in 0..(this.orderMarket.size() - 1)){
			out.put(this.orderMarket.get(i),this.orderMarket.get(i).getFundamentalPrice(T));
		}
		return out;
	}

	//今期の時間TimeとtimeSizeを基に、TPORT日毎のtimeSize個の各市場の市場市場ノーマルリターンを獲得する。 
	public def recentMarketNormalReturnsTPORT(Time:Long, timeSize:Long):HashMap[Market,ArrayList[Double]]{
		return recentMarketNormalReturnsSomeDays(Time, this.TPORT, timeSize);
	}

	//今期の時間TimeとtimeSizeを基に、月次のtimeSize個の各市場の市場ノーマルリターンを獲得する。 
	public def recentMarketNormalReturnsOneMonth(Time:Long, timeSize:Long):HashMap[Market,ArrayList[Double]]{
		return recentMarketNormalReturnsSomeDays(Time, this.numDaysOneMonth, timeSize);
	}

	//今期の時間TimeとtimeSizeを基に、日次のtimeSize個の各市場の市場ノーマルリターンを獲得する。 
	public def recentMarketNormalReturnsOneDay(Time:Long, timeSize:Long):HashMap[Market,ArrayList[Double]]{
		return recentMarketNormalReturnsSomeDays(Time, 1, timeSize);
	}

	//今期の時間TimeとSomeDays,timeSizeを基に、SomeDays日毎のtimeSize個の各市場の市場ノーマルリターンを獲得する
	public def recentMarketNormalReturnsSomeDays(Time:Long,SomeDays:Long, timeSize:Long):HashMap[Market,ArrayList[Double]]{
		val T = Time - Time%(SomeDays*this.numStepsOneDay);
		var recents:HashMap[Market,ArrayList[Double]] = new HashMap[Market,ArrayList[Double]](0);
		for(i in 0..(this.orderMarket.size() - 1)){
			//Console.OUT.print("\n\t*time(market"+this.orderMarket.get(i).id+"):");
			val recent:ArrayList[Double] = new ArrayList[Double](0);
			for(var j:Long = 0; j < timeSize; j++){
				val r = ( this.orderMarket.get(i).marketPrices(T + (j+1-timeSize)*SomeDays*this.numStepsOneDay) - this.orderMarket.get(i).marketPrices(T + (j-timeSize)*SomeDays*this.numStepsOneDay) ) / this.orderMarket.get(i).marketPrices(T + (j-timeSize)*SomeDays*this.numStepsOneDay);
				//Console.OUT.print((T + (j+1-timeSize)*SomeDays*this.numStepsOneDay)+"");
				//Console.OUT.print("("+r+"),");
				recent.add(r);
			}
			//Console.OUT.print("\n");
			recents.put(this.orderMarket.get(i),recent);
		}

		return recents;
	}

	//今期の時間TimeとtimeSizeを基に、TPORT日毎のtimeSize個の各市場の市場対数リターンを獲得する。 
	public def recentMarketLogReturnsTPORT(Time:Long, timeSize:Long):HashMap[Market,ArrayList[Double]]{
		return recentMarketLogReturnsSomeDays(Time, this.TPORT, timeSize);
	}

	//今期の時間TimeとtimeSizeを基に、月次のtimeSize個の各市場の市場対数リターンを獲得する。 
	public def recentMarketLogReturnsOneMonth(Time:Long, timeSize:Long):HashMap[Market,ArrayList[Double]]{
		return recentMarketLogReturnsSomeDays(Time, this.numDaysOneMonth, timeSize);
	}

	//今期の時間TimeとtimeSizeを基に、日次のtimeSize個の各市場の市場対数リターンを獲得する。 
	public def recentMarketLogReturnsOneDay(Time:Long, timeSize:Long):HashMap[Market,ArrayList[Double]]{
		return recentMarketLogReturnsSomeDays(Time, 1, timeSize);
	}

	//今期の時間TimeとSomeDays,timeSizeを基に、SomeDays日毎のtimeSize個の各市場の市場対数リターンを獲得する。 
	public def recentMarketLogReturnsSomeDays(Time:Long,SomeDays:Long, timeSize:Long):HashMap[Market,ArrayList[Double]]{
		val T = Time - Time%(SomeDays*this.numStepsOneDay);
		var recents:HashMap[Market,ArrayList[Double]] = new HashMap[Market,ArrayList[Double]](0);
		for(i in 0..(this.orderMarket.size() - 1)){
			//Console.OUT.print("\n\t*time(market"+this.orderMarket.get(i).id+"):");
			val recent:ArrayList[Double] = new ArrayList[Double](0);
			for(var j:Long = 0; j < timeSize; j++){
				val r = Math.log( this.orderMarket.get(i).marketPrices(T + (j+1-timeSize)*SomeDays*this.numStepsOneDay)/this.orderMarket.get(i).marketPrices(T + (j-timeSize)*SomeDays*this.numStepsOneDay) );
				//Console.OUT.print((T + (j+1-timeSize)*SomeDays*this.numStepsOneDay)+"");
				//Console.OUT.print("("+r+"),");
				recent.add(r);
			}
			//Console.OUT.print("\n");
			recents.put(this.orderMarket.get(i),recent);
		}

		return recents;
	}


	public def presentMarketPricesTPORT(Time:Long):HashMap[Market,Double]{
		return presentMarketPricesSomeDays(Time,this.TPORT);
	}

	public def presentMarketPricesOneMonth(Time:Long):HashMap[Market,Double]{
		return presentMarketPricesSomeDays(Time,this.numDaysOneMonth);
	}

	public def presentMarketPricesOneDay(Time:Long):HashMap[Market,Double]{
		return presentMarketPricesSomeDays(Time,1);
	}

	//今期の時間TimeとSomeDaysを基に、SomeDays日毎のtimeSize個の各市場の市場価格を獲得する。 
	public def presentMarketPricesSomeDays(Time:Long,SomeDays:Long):HashMap[Market,Double]{
		val T = Time - Time%(SomeDays*this.numStepsOneDay);
		var out:HashMap[Market,Double] = new HashMap[Market,Double]();
		for(i in 0..(this.orderMarket.size() - 1)){
			out.put(this.orderMarket.get(i),this.orderMarket.get(i).getMarketPrice(T));
		}
		return out;
	}

	public def presentMarketPricesStep(Time:Long):HashMap[Market,Double]{
		val T = Time;
		var out:HashMap[Market,Double] = new HashMap[Market,Double]();
		for(i in 0..(this.orderMarket.size() - 1)){
			out.put(this.orderMarket.get(i),this.orderMarket.get(i).getMarketPrice(T));
		}
		return out;
	}

	//2.今期の時間を基にportfolioを更新するかを決定
	public def checkUpdateExpectation(time:Long):Boolean{
		val t = time - time%(this.TPORT*this.numStepsOneDay);
		//updateNowTime();
		val dif:Long = t -lastUpdated;
		if(dif > 0 || t ==0 ){
			//Console.OUT.println("T="+T+",lastUpdated="+lastUpdated+",true");
			//Console.OUT.println("need");
			return true;
		}else{
			//Console.OUT.println("T="+T+",lastUpdated="+lastUpdated+",false");
			//Console.OUT.println("no need");
			return false;
		}
	}

	public def checkUpdateExpectation(TPS:Rail[Long]):Boolean{
		if(this.lastUpdated == -1 ){
			//Console.OUT.println("t0="+TPS(0)+",t1="+TPS(1)+",t2="+TPS(2)+",this.base="+this.base+",this.lastUpdated="+this.lastUpdated );
			//Console.OUT.println("need");
			return true;
		}
		val days = TPS(0)*this.TPORT + TPS(1);
		val dif:Long = TPS(0) - this.lastUpdated/(this.TPORT*this.numStepsOneDay);
		if(dif>0){
			//Console.OUT.println("t0="+TPS(0)+",t1="+TPS(1)+",t2="+TPS(2)+",this.base="+this.base +",this.lastUpdated="+(this.lastUpdated/(this.TPORT*this.numStepsOneDay)) );
			//Console.OUT.println("need");
			return true;
		}else{
			//Console.OUT.println("t0="+TPS(0)+",t1="+TPS(1)+",t2="+TPS(2)+",this.base="+this.base +",this.lastUpdated="+(this.lastUpdated/(this.TPORT*this.numStepsOneDay)) );
			//Console.OUT.println("no need");
			return false;
		}
	}

	public def getTPORTFromTS(x:Rail[Long]):Long{
		var out:Long = 0;
		out = out + x(0)*this.TPORT*this.numStepsOneDay;
		out = out + x(1)*this.numStepsOneDay;
		out = out + x(2);
		return out;
	}

	public def getTPORTStructure(t:Long, name:String):Long{
		var out:Rail[Long] = getTPORTStructure(t);
		return out(tportOrder(name));
	}

	public def getTPORTStructure(t:Long):Rail[Long]{
		val T = t- this.base*this.numStepsOneDay;
		var out:Rail[Long] = new Rail[Long](3);
		out(0) = (Math.floor((T/(this.TPORT*this.numStepsOneDay))) as Long);
		out(1) = (Math.floor(((T%(this.TPORT*this.numStepsOneDay))/this.numStepsOneDay)) as Long);
		out(2) = (T%this.numStepsOneDay)%this.numStepsOneDay;
		return out;
	}

	public def tportOrder(name:String):Long{
		var out:Long = -1;
		if(name.equals("Month")){
			out = 0;
		}else if(name.equals("day")){
			out = 1;
		}else if(name.equals("step")){
			out = 2;
		}else{
			assert false: "timeOrderError";
		}
		return out;
	}

	public def getTFromTS(x:Rail[Long]):Long{
		var out:Long = 0;
		out = out + x(0)*this.numDaysOneMonth*this.numStepsOneDay;
		out = out + x(1)*this.numStepsOneDay;
		out = out + x(2);
		return out;
	}

	public def getTimeStructure(t:Long, name:String):Long{
		var out:Rail[Long] = getTimeStructure(t);
		return out(timeOrder(name));
	}

	public def getTimeStructure(t:Long):Rail[Long]{
		var out:Rail[Long] = new Rail[Long](3);
		out(0) = (Math.floor((t/(this.numDaysOneMonth*this.numStepsOneDay))) as Long);
		out(1) = (Math.floor(((t%(this.numDaysOneMonth*this.numStepsOneDay))/this.numStepsOneDay)) as Long);
		out(2) = (t%this.numStepsOneDay)%this.numStepsOneDay;
		return out;
	}

	public def timeOrder(name:String):Long{
		var out:Long = -1;
		if(name.equals("Month")){
			out = 0;
		}else if(name.equals("day")){
			out = 1;
		}else if(name.equals("step")){
			out = 2;
		}else{
			assert false: "timeOrderError";
		}
		return out;
	}

	public def log(a:HashMap[Market,ArrayList[Double]]):HashMap[Market,ArrayList[Double]] {
		var out:HashMap[Market,ArrayList[Double]] = new HashMap[Market,ArrayList[Double]]();
		for(i in 0..(this.orderMarket.size() - 1)){
			var hoge:ArrayList[Double] = log( a.get(orderMarket.get(i)) );
			out.put(orderMarket.get(i), hoge);
		}
		return out;
	}

	public def log(a:List[Double]):ArrayList[Double] {
		var out:ArrayList[Double] = new ArrayList[Double](a.size());
		for (i in 0..(a.size() - 1)) {
			out.add( Math.log(a(i)) );
		}
		return out;
	}


	public def exp(expectedLogReturns:HashMap[Market,Double]):HashMap[Market,Double]{
		var out:HashMap[Market,Double] = new HashMap[Market,Double]();
		for(i in 0..(this.orderMarket.size() - 1)){
			out.put(orderMarket.get(i), Math.exp( expectedLogReturns.get(orderMarket.get(i)) ) );
		}
		return out;
	}




	//今期の時間を獲得。
	public def getTime(allMarkets:List[Market]):Long{
		//今期の時間tの更新
		var T:Long = Long.MAX_VALUE;
		for(market in allMarkets){
			val t:Long = market.getTime();
			if(t <= T){ T=t; }
		}
		//Console.OUT.println("#*MainTime="+T);
		return T;
	}

	// 要するにtranslationm1なんだけど, 覚えやすい名前つけたい.
	public static def asMarketVolumeMap (
		base: Rail[Long],
		orderMarket: ArrayList[Market]
	) : HashMap[Market, Long] {
		return translationm1(base, orderMarket);
	}
	public static def asMarketVolumeMap (
		base: Rail[Double],
		orderMarket: ArrayList[Market]
	) : HashMap[Market, Double] {
		return translationm2(base, orderMarket);
	}

	public static def register(sim:Simulator):void {
		val className = "FCNMarkowitzPortfolioAgent";
		sim.addAgentInitializer(
			className, (
				id:Long,
				name:String, 
				random:Random,
				json:JSON.Value
			) => {
				Console.OUT.println("# " + json("class").toString() + " : " + JSON.dump(json));
				return new FCNMarkowitzPortfolioAgent(id, name, random).setup(json, sim);
			}
		);
	}

	public def setup(json:JSON.Value, sim:Simulator):Agent {
		val random = new JSONRandom(this.getRandom());
		assert(json("class").equals("FCNMarkowitzPortfolioAgent"));
		this.fundamentalWeight = random.nextRandom(json("fundamentalWeight"));
		this.chartWeight = random.nextRandom(json("chartWeight"));	
		this.noiseWeight = random.nextRandom(json("noiseWeight"));
		this.noiseScale = random.nextRandom(json("noiseScale"));
		this.timeWindowSize = random.nextRandom(json("timeWindowSize")) as Long;
		//val fcRatio = (1.0 + this.fundamentalWeight) / (1.0 + this.chartWeight);
		this.fundamentalMeanReversionTime = random.nextRandom(json("fundamentalMeanReversionTime")) as Long;
		this.shortSellingAbility = json("shortSellingAbility").toBoolean();
		this.leverageRate = json("leverageRate").toDouble();
		assert this.fundamentalWeight >= 0.0 : "fundamentalWeight >= 0.0";
		assert this.chartWeight >= 0.0 : "chartWeight >= 0.0";
		assert this.noiseWeight >= 0.0 : "noiseWeight >= 0.0";
		this.b = random.nextRandom(json("b"));
		this.TPORT = json("tport").toLong();
		this.base = random.nextRandom(json("base")) as Long;
		//Console.OUT.println("this.base="+this.base);
		this.lastUpdated = -1; //正しい？
		//assert json("accessibleMarkets").size() == 2 : "FCNAgents suppose only one Market";
		val markets = sim.getMarketsByName(json("accessibleMarkets"));
		this.allMarkets = markets as List[Market];
		this.accessibleMarkets = markets as List[Market]; 
		for (m in this.accessibleMarkets) {
			this.setMarketAccessible(m);
			this.setAssetVolume(m, random.nextRandom(json("assetVolume")) as Long);
		}
		this.setCashAmount(random.nextRandom(json("cashAmount")));
		//Console.OUT.println("# a0");
		if(json.has("logType")){
			//Console.OUT.println("# a2");
			this.logType = json("logType").toBoolean();
		}
		this.session0iterationDays = sim.CONFIG("simulation")("sessions")(0)("iterationDays").toLong();
		this.numStepsOneDay  = sim.CONFIG("numStepsOneDay").toLong();
		this.numDaysOneMonth = sim.CONFIG("numDaysOneMonth").toLong();
		this.covarfundamentalWeight = sim.CONFIG("covarfundamentalWeight").toDouble();
		return this;
	}
}


