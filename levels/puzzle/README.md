# Puzzle Level Fixtures

Godot looks here first for approved puzzle fixtures:

```text
res://levels/puzzle/level-001.json
res://levels/puzzle/level-002.json
...
```

If a shipped fixture is missing during development, the Puzzle scene builds a temporary open-board fallback and still runs it through the C# bridge.

Generated C# artifacts can be copied here from:

```text
sim/generated/level-001/starting-fixture.json
```

## Shipped Levels

Each shipped level has four files:

- `level-NNN.json`: separated player start fixture loaded by Godot.
- `level-NNN-solution.json`: verified backend solution fixture.
- `level-NNN-solution.txt`: ASCII solution map for inspection.
- `level-NNN-definition.json`: seed, cells, start layout, solution layout, and solver summary.

Current first-twenty solution maps:

```text
001:
AB
CD

002:
BE.
CDA

003:
FDA
CBE

004:
ED.
GF.
ACB

005:
FHC
BAD
EG.

006:
DAF
BIE
GHC

007:
GEBA
FDHJ
CI..

008:
IBEA
JCGH
KFD.

009:
IKHL
CEGA
JBFD

010:
FGHLMA
CIBJKD
E.....

011:
KBCJ
HEIL
ANDF
..MG

012:
HNIF
AODE
MJGC
.LKB

013:
COMJPL
AKHNBF
GE..ID

014:
MEKLOBN
QAFIJHP
D....CG

015:
QOEBLCN
DPGHIMA
KR...FJ

016:
RPQEOBA
NJKCFDG
HISML..

017:
SKTCAE
GILOFQ
DNBPMJ
....RH

018:
DGKBM
FJAIR
CQTSL
PHOUN
E....

019:
BGJDK
VSOCU
RINTQ
LHPFE
AM...

020:
WKCJOFA
HPQBDIV
ETGNRMU
.....LS
```
