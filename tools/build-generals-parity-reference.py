"""Compile unmodified original routine bodies with explicit environment adapters.

The oracle executes the original routines, not a second translation of the port.
This covers the named routines only, not complete skirmish AI or full-game parity.
"""
import argparse
import hashlib
import itertools
import json
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]


def extract(path, signature):
    text = path.read_text(encoding='utf-8-sig')
    start = text.index(signature)
    text = text[start:]
    brace = text.index('{')
    # Mask comments/quoted strings so braces in them cannot end the function.
    masked = re.sub(r'''//[^\n]*|/\*[\s\S]*?\*/|"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*' '''.strip(),
                    lambda match: ' ' * len(match[0]), text)
    depth = 1
    end = brace + 1
    while depth:
        depth += (masked[end] == '{') - (masked[end] == '}')
        end += 1
    return text[:end]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, default=Path('D:/GitHub/CnC_Generals_Zero_Hour'))
    parser.add_argument('--compiler', default='g++')
    parser.add_argument('--output', type=Path, default=ROOT / 'validation-output/full-game-port/native-reference')
    args = parser.parse_args()
    code = args.source / 'GeneralsMD/Code/GameEngine'
    requests = [
        ('Source/GameLogic/AI/AISkirmishPlayer.cpp', 'void AISkirmishPlayer::doBaseBuilding( void )'),
        ('Source/GameLogic/AI/AISkirmishPlayer.cpp', 'void AISkirmishPlayer::doTeamBuilding( void )'),
        ('Source/GameLogic/AI/AIGuardRetaliate.cpp', 'Bool GuardRetaliateExitConditions::shouldExit(const StateMachine* machine) const'),
        ('Include/Common/GameCommon.h', 'inline Real ConvertDurationFromMsecsToFrames(Real msec)'),
        ('Source/Common/INI/INI.cpp', 'void INI::parseDurationUnsignedInt( INI *ini, void * /*instance*/, void *store, const void* /*userData*/ )'),
    ]
    functions, provenance = [], []
    for relative, signature in requests:
        path = code / relative
        body = extract(path, signature)
        functions.append(body)
        provenance.append(dict(path=path.relative_to(args.source).as_posix(), signature=signature,
            source_sha256=hashlib.sha256(path.read_bytes()).hexdigest(), function_sha256=hashlib.sha256(body.encode()).hexdigest()))
    header = r'''
#include <iostream>
#include <cmath>
#include <string>
using Real=float; using Bool=bool; using UnsignedInt=unsigned int; using Int=int;
constexpr bool TRUE=true, FALSE=false;
constexpr int LOGICFRAMES_PER_SECOND=30;
constexpr Real LOGICFRAMES_PER_MSEC_REAL=Real(30)/Real(1000);
struct Player { bool enabled; bool getCanBuildBase(){return enabled;} bool getCanBuildUnits(){return enabled;} };
struct AISkirmishPlayer {
 Player* m_player; bool m_readyToBuildStructure, m_readyToBuildTeam;
 int m_structureTimer, m_buildDelay, m_teamTimer, m_teamDelay;
 int resetTimer, resetDelay, queueCalls=0, processCalls=0;
 std::string events;
 void queueUnits(){queueCalls++;events+='Q';}
 void processBaseBuilding(){processCalls++;events+='P';m_readyToBuildStructure=false;m_structureTimer=resetTimer;m_buildDelay=resetDelay;}
 void processTeamBuilding(){processCalls++;events+='P';m_readyToBuildTeam=false;m_teamTimer=resetTimer;m_teamDelay=resetDelay;}
 void doBaseBuilding(); void doTeamBuilding();
};
struct Coord3D { Real x,y,z; Real lengthSqr()const{return x*x+y*y+z*z;} };
template<class T> T sqr(T value){return value*value;}
struct Object {Coord3D pos; Real range; const Coord3D* getPosition()const{return &pos;} };
struct StateMachine {Object *goal,*owner;Object* getGoalObject()const{return goal;} Object* getOwner()const{return owner;} };
struct Logic {int frame; int getFrame(){return frame;}} logic;
Logic* TheGameLogic=&logic;
struct AIGuardRetaliateMachine {static Real getStdGuardRange(const Object* o){return o->range;}};
struct GuardRetaliateExitConditions {
 enum {ATTACK_ExitIfOutsideRadius=1,ATTACK_ExitIfExpiredDuration=2,ATTACK_ExitIfNoUnitFound=4};
 int m_conditionsToConsider, m_attackGiveUpFrame; Coord3D m_center; Real m_radiusSqr;
 Bool shouldExit(const StateMachine* machine)const;
};
UnsignedInt scanUnsignedInt(const char* text){return std::stoul(text);}
struct INI {std::string value;const char* getNextToken(){return value.c_str();}
 static void parseDurationUnsignedInt(INI*,void*,void*,const void*);};
'''
    main_source = r'''
int main(){char kind;while(std::cin>>kind){
 if(kind=='T'){int mode,enabled,ready,timer,delay,resetTimer,resetDelay,steps;
 std::cin>>mode>>enabled>>ready>>timer>>delay>>resetTimer>>resetDelay>>steps;
 Player p{bool(enabled)};AISkirmishPlayer a{};a.m_player=&p;
 a.m_readyToBuildStructure=a.m_readyToBuildTeam=ready;
 a.m_structureTimer=a.m_teamTimer=timer;a.m_buildDelay=a.m_teamDelay=delay;
 a.resetTimer=resetTimer;a.resetDelay=resetDelay;
 for(int i=0;i<steps;i++){a.events.clear();if(mode)a.doTeamBuilding();else a.doBaseBuilding();
 std::cout<<(mode?a.m_readyToBuildTeam:a.m_readyToBuildStructure)<<' '
 <<(mode?a.m_teamTimer:a.m_structureTimer)<<' '<<(mode?a.m_teamDelay:a.m_buildDelay)<<' '
 <<a.queueCalls<<' '<<a.processCalls<<' '<<(a.events.empty()?"-":a.events)<<'\n';}}
 else if(kind=='D'){INI ini;std::cin>>ini.value;UnsignedInt result=0;INI::parseDurationUnsignedInt(&ini,nullptr,&result,nullptr);std::cout<<result<<'\n';}
 else if(kind=='G'){int has;GuardRetaliateExitConditions c{};Object target{},owner{};
 std::cin>>has>>c.m_conditionsToConsider>>logic.frame>>c.m_attackGiveUpFrame
 >>target.pos.x>>target.pos.y>>target.pos.z>>owner.pos.x>>owner.pos.y>>owner.pos.z>>c.m_radiusSqr>>owner.range;
 StateMachine machine{has?&target:nullptr,&owner};std::cout<<c.shouldExit(&machine)<<'\n';}
 else return 2;
 }}
'''
    out = args.output
    out.mkdir(parents=True, exist_ok=True)
    cpp = out / 'reference.cpp'
    cpp.write_text('// Generated from original EA routines; GPL-3.0-or-later.\n' + header + '\n'.join(functions) + main_source)
    exe = out / 'reference.exe'
    command = [args.compiler, '-std=c++17', '-O0', '-ffp-contract=off', str(cpp), '-o', str(exe)]
    compiled = subprocess.run(command, capture_output=True, text=True)
    (out / 'compile.log').write_text(compiled.stdout + compiled.stderr + f'\nexit={compiled.returncode}\n')
    if compiled.returncode:
        raise SystemExit(compiled.stderr)
    timing = []
    for mode, enabled, ready, timer, delay, reset_delay in itertools.product(
            [0,1], [0,1], [0,1], [-1,0,1,2,90,91,500], [-1,0,1,2,60], [0,7]):
        timing.append(dict(input=[mode,enabled,ready,timer,delay,4,reset_delay,8]))
    durations = [0,1,2,16,17,33,34,66,67,99,100,101,499,500,501,999,1000,1001,10000,33333,100000,999999,1000000,16777217,2000000000]
    guards = []
    for has, flags, geometry in itertools.product([0,1], range(8), [
        [0,0,500,0,0,600,100,10], [10,0,900,10,0,1000,100,10],
        [10.001,0,0,0,0,0,100,10], [0,0,0,10.001,0,0,100,10],
        [6,8,500,3,4,-200,100,5],
        # Original Real fields round on assignment, before the range comparison.
        [1,0,0,0,0,0,0.999999999,10],
        [0,0,0,1.0000001192092896,0,0,100,1.00000008]]):
        for frame in [9,10]:
            guards.append([has,flags,frame,10,*geometry])
    requests_text = ''.join('T '+' '.join(map(str,r['input']))+'\n' for r in timing)
    requests_text += ''.join(f'D {v}\n' for v in durations)
    requests_text += ''.join('G '+' '.join(map(str,r))+'\n' for r in guards)
    run = subprocess.run([str(exe)], input=requests_text, capture_output=True, text=True)
    (out / 'execution.stdout.log').write_text(run.stdout)
    (out / 'execution.stderr.log').write_text(run.stderr)
    if run.returncode or run.stderr:
        raise SystemExit(f'Original reference failed: {run.returncode} {run.stderr}')
    lines = iter(run.stdout.splitlines())
    for row in timing:
        row['expected'] = []
        for _ in range(row['input'][-1]):
            parts = next(lines).split()
            row['expected'].append([*map(int,parts[:5]),parts[5]])
    duration_cases = [dict(input=v, expected=int(next(lines))) for v in durations]
    guard_cases = [dict(input=v, expected=int(next(lines))) for v in guards]
    assert next(lines, None) is None
    data = dict(scope='Isolated original scheduler control flow, duration conversion and guard exit predicate. Environment callbacks are adapters; full AI is not covered.',
        provenance=provenance, compiler_command=command, timing=timing, durations=duration_cases, guards=guard_cases)
    dest = ROOT / 'tests/fixtures/generals_native_reference.json'
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_text(json.dumps(data,separators=(',',':'))+'\n')
    print(json.dumps(dict(timing_cases=len(timing),timing_steps=sum(len(r['expected']) for r in timing),duration_cases=len(duration_cases),guard_cases=len(guard_cases),source_functions=len(functions))))


if __name__ == '__main__':
    main()
