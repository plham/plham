#/bin/bash
# This is to generate a JSON file for large-scale simulations,
# composed of N spot markets (assets).
# Only the # of spot markets is set by the first argument.

if [ $# -lt 1 ]; then
	echo 'Usage: $ bash Parallel.json.sh NUM_SPOTS >config.json'
	exit
fi

N=${1:-10}

SPOTMARKETS=
for i in $(seq 1 $N); do
	SPOTMARKETS+="\"SpotMarket-${i}\", "
done
SPOTMARKETS=${SPOTMARKETS%, }

FCNAGENTS=
for i in $(seq 1 $N); do
	FCNAGENTS+="\"FCNAgents-${i}\", "
done
FCNAGENTS=${FCNAGENTS%, }

cat <<EOH
{
	"simulation": {
		"markets": [${SPOTMARKETS}, "IndexMarket-I"],
		"agents": [${FCNAGENTS}, "FCNAgents-I", "ArbitrageAgents"],
		"sessions": [
			{	"sessionName": 1,
				"iterationSteps": 500,
				"withOrderPlacement": true,
				"withOrderExecution": true,
				"withPrint": true,
				"maxNormalOrders": 10000000000, "MEMO": "EVERYONE",
				"maxHifreqOrders": 1,
				"events": ["FundamentalPriceShock"]
			}
		]
	},

	"FundamentalPriceShock": {
		"class": "FundamentalPriceShock",
		"target": "SpotMarket-1",
		"triggerTime": 0,    "MEMO": "At the beginning of the session 2",
		"priceChangeRate": -0.1,    "MEMO": "Sign: negative for down; positive for up; zero for no change",
		"enabled": true
	},

	"SpotMarket": {
		"class": "Market",
		"tickSize": 0.00001,
		"marketPrice": 300.0,
		"outstandingShares": 25000
	},
EOH

for i in $(seq 1 $N); do
cat <<EOH
	"SpotMarket-${i}": {
		"extends": "SpotMarket"
	},
EOH
done

cat <<EOH
	"IndexMarket-I": {
		"class": "IndexMarket",
		"tickSize": 0.00001,
		"marketPrice": 300.0,
		"outstandingShares": 25000,
		"markets": [${SPOTMARKETS%, }]
	},

	"FCNAgent": {
		"class": "FCNAgent",
		"numAgents": 500,

		"MEMO": "Agent class",
		"markets": ["Market"],
		"assetVolume": 50,
		"cashAmount": 10000,

		"MEMO": "FCNAgent class",
		"fundamentalWeight": {"expon": [1.0]},
		"chartWeight": {"expon": [0.0]},
		"noiseWeight": {"expon": [1.0]},
		"noiseScale": 0.001,
		"timeWindowSize": [100, 200],
		"orderMargin": [0.0, 0.1]
	},
EOH

for i in $(seq 1 $N); do
cat <<EOH
	"FCNAgents-${i}": {
		"extends": "FCNAgent",
		"markets": ["SpotMarket-${i}"],
		"fundamentalWeight": {"expon": [1.0]},
		"chartWeight": {"expon": [0.0]},
		"noiseWeight": {"expon": [1.0]}
	},
EOH
done

cat <<EOH
	"FCNAgents-I": {
		"extends": "FCNAgent",
		"markets": ["IndexMarket-I"],
		"fundamentalWeight": {"expon": [0.5]},
		"chartWeight": {"expon": [0.0]},
		"noiseWeight": {"expon": [1.0]}
	},

	"ArbitrageAgents": {
		"class": "ArbitrageAgent",
		"numAgents": 100,

		"markets": ["IndexMarket-I"],
		"assetVolume": 50,      "NOTE":"per market",
		"cashAmount": 150000,    "NOTE":"total",

		"orderVolume": 1,
		"orderThresholdPrice": 1.0
	}
}
EOH

