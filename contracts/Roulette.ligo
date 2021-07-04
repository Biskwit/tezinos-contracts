type roulette_Bet is record
  player : address;
  betType : nat;
  number : nat;
end;

type state is record
  initialized : bool;
  betAmount : tez;
  necessaryBalance : tez;
  nextRoundTimestamp : nat;
  creator : address;
  maxTezInContract : tez;
  winnings : map(address, tez);
  payouts : map(nat, nat);
  numberRange : map(nat, nat);
  bets : map(nat, roulette_Bet);
  bannedUsers: set(address);
end;

type betParams is record
  number : nat;
  betType : nat;
end;

type spinWheelParams is record
  result : nat;
end;

type banParams is record
  player : address;
end;

type entryAction is
  | Initialize of unit
  | Fund of unit
  | SpinWheel of spinWheelParams
  | Bet of betParams
  | BanUser of banParams
  | UnBanUser of banParams

const roulette_Bet_0 : roulette_Bet = record [ 
  player = ("tz1ZDcc6MGxidty2jivtWBjnuo1mcSXf4Mmr" : address);
  betType = 0n;
  number = 0n ];

function cAssert(const p : bool; const s: string) : unit is
  block { if p then skip else failwith(s) }
  with unit

function banUser (var self : state; const user : address) : state is
  block {
    cAssert(Tezos.sender = self.creator, "Tezos.sender = self.creator");
    if not (self.bannedUsers contains user)
        then self.bannedUsers := Set.add(user, self.bannedUsers);
    else failwith ("user already banned");
  } with self

function unbanUser (var self : state; const user : address) : state is
  block {
    cAssert(Tezos.sender = self.creator, "Tezos.sender = self.creator");
    if (self.bannedUsers contains user)
        then self.bannedUsers := Set.remove(user, self.bannedUsers);
    else failwith ("user already unbanned");
  } with self

function init (const self : state) : (state) is block {
    cAssert(self.initialized = False, "Creator already exist");
    self.initialized := True;
    self.creator := Tezos.sender;
    self.necessaryBalance := 0tez;
    self.nextRoundTimestamp := abs(now - ("1970-01-01T00:00:00Z" : timestamp));
    self.payouts := map
      0n -> 2n;
      1n -> 3n;
      2n -> 3n;
      3n -> 2n;
      4n -> 2n;
      5n -> 36n;
    end;
    self.numberRange := map
      0n -> 1n;
      1n -> 2n;
      2n -> 2n;
      3n -> 1n;
      4n -> 1n;
      5n -> 36n;
    end;
    self.betAmount := 1tez;
    self.maxTezInContract := 10tez;
} with (self);

function bet (const self : state; const number : nat; const betType : nat) : (state) is block {
    cAssert(not(self.bannedUsers contains Tezos.sender), "banned user");
    cAssert(Tezos.amount = self.betAmount, "Tezos.amount = self.betAmount");
    cAssert(((betType >= 0n) and (betType <= 5n)), "(betType >= 0n) and (betType <= 5n)");
    cAssert((number >= 0n) and (number <= (case self.numberRange[betType] of | None -> 0n | Some(x) -> x end)), "Out of range");
    const payoutForThisBet : tez = ((case self.payouts[betType] of | None -> 0n | Some(x) -> x end) * Tezos.amount);
    const provisionalBalance : tez = (self.necessaryBalance + payoutForThisBet);
    cAssert((provisionalBalance < Tezos.balance), "provisionalBalance < Tezos.balance");
    self.necessaryBalance := (self.necessaryBalance + payoutForThisBet);
    self.bets[size(self.bets)] := record [ betType = betType;
      player = Tezos.sender;
      number = number ];
} with (self);

function takeProfits (const self : state) : (list(operation)) is block {
    const res_amount : tez = Tezos.balance - self.maxTezInContract;
    assert(res_amount > 0tez);
    const receiver : contract (unit) =
        case (Tezos.get_contract_opt(self.creator): option(contract(unit))) of
          Some (contract) -> contract
        | None -> (failwith ("Not a contract") : (contract(unit)))
        end;
      const op0 : operation = transaction(unit, res_amount, receiver);
} with (list [op0]);

function fund(const self : state) : (state) is block {
    skip
} with (self);

function cashOut (const self : state) : (list(operation) * state) is
  block {
    const player : address = Tezos.sender;
    const res_amount : tez = (case self.winnings[player] of | None -> 0tez | Some(x) -> x end);
    assert((res_amount > 0tez));
    assert((res_amount <= Tezos.balance));
    self.winnings[player] := 0tez;
    const op0 : operation = transaction((unit), res_amount, (get_contract(player) : contract(unit)));
  } with (list [op0], self);


function spinWheel(const self : state; const result : nat) : (list(operation) * state) is
  block {
    cAssert(Tezos.sender = self.creator, "Tezos.sender = self.creator");
    cAssert((size(self.bets) > 0n), "size(self.bets) > 0n");
    //cAssert((abs(now - ("1970-01-01T00:00:00Z" : timestamp)) > self.nextRoundTimestamp), "now>self.nextRoundTimestamp");
    self.nextRoundTimestamp := abs(now - ("1970-01-01T00:00:00Z" : timestamp));
    for i := 0 to int (size(self.bets)) block {
      const won : bool = False;
      const b : roulette_Bet = (case self.bets[abs(i)] of | None -> roulette_Bet_0 | Some(x) -> x end);
      if (result = 0n) then block {
        won := ((b.betType = 5n) and (b.number = 0n));
      } else block {
        if (b.betType = 5n) then block {
          won := (b.number = result);
        } else block {
          if (b.betType = 4n) then block {
            if (b.number = 0n) then block {
              won := ((result mod 2n) = 0n);
            } else block {
              skip
            };
            if (b.number = 1n) then block {
              won := ((result mod 2n) = 1n);
            } else block {
              skip
            };
          } else block {
            if (b.betType = 3n) then block {
              if (b.number = 0n) then block {
                won := (result <= 18n);
              } else block {
                skip
              };
              if (b.number = 1n) then block {
                won := (result >= 19n);
              } else block {
                skip
              };
            } else block {
              if (b.betType = 2n) then block {
                if (b.number = 0n) then block {
                  won := (result <= 12n);
                } else block {
                  skip
                };
                if (b.number = 1n) then block {
                  won := ((result > 12n) and (result <= 24n));
                } else block {
                  skip
                };
                if (b.number = 2n) then block {
                  won := (result > 24n);
                } else block {
                  skip
                };
              } else block {
                if (b.betType = 1n) then block {
                  if (b.number = 0n) then block {
                    won := ((result mod 3n) = 1n);
                  } else block {
                    skip
                  };
                  if (b.number = 1n) then block {
                    won := ((result mod 3n) = 2n);
                  } else block {
                    skip
                  };
                  if (b.number = 2n) then block {
                    won := ((result mod 3n) = 0n);
                  } else block {
                    skip
                  };
                } else block {
                  if (b.betType = 0n) then block {
                    if (b.number = 0n) then block {
                      if ((result = 2n) or (result = 4n) or (result = 6n) or (result = 8n) or (result = 10n) or (result = 11n) or (result = 13n) or (result = 15n) or (result = 17n) or (result = 20n) or (result = 22n) or (result = 24n) or (result = 26n) or (result = 28n) or (result = 29n) or (result = 31n) or (result = 33n) or (result = 35n)) then block { // 2, 4, 6, 8, 10, 11, 13, 15, 17, 20, 22, 24, 26, 28, 29, 31, 33, 35
                        won := True;
                      } else block {
                        won := False;
                      };
                    } else block {
                      if ((result = 1n) or (result = 3n) or (result = 5n) or (result = 7n) or (result = 9n) or (result = 12n) or (result = 14n) or (result = 16n) or (result = 18n) or (result = 19n) or (result = 21n) or (result = 23n) or (result = 25n) or (result = 27n) or (result = 30n) or (result = 32n) or (result = 34n) or (result = 36n)) then block { //1, 3, 5, 7, 9, 12, 14, 16, 18, 19, 21, 23, 25, 27, 30, 32, 34, 36
                        won := True;
                      } else block {
                        won := False;
                      };
                    };
                  } else block {
                    skip
                  };
                };
              };
            };
          };
        };
      };
      if (won) then block {
        self.winnings[b.player] := ((case self.winnings[b.player] of | None -> 0tez | Some(x) -> x end) + (self.betAmount * (case self.payouts[b.betType] of | None -> 0n | Some(x) -> x end)));
      } else block {
        skip
      };
    };

    self.bets := (Map.empty : map(nat, roulette_Bet));
    self.necessaryBalance := 0tez;
    assert(Tezos.balance > self.maxTezInContract);

    const tmp_1 : (list(operation) * state) = cashOut(self);
    var listOp : list(operation) := tmp_1.0;
    var store : state := tmp_1.1;
  } with (listOp, store);

function main (const action : entryAction; const self : state) : (list(operation) * state) is
  block {
    skip
  } with case action of
  | Initialize -> ((nil : list(operation)), init(self))
  | Fund -> ((nil : list(operation)), fund(self))
  | Bet(params) -> ((nil : list(operation)), bet(self, params.number, params.betType))
  | SpinWheel(params) -> spinWheel(self, params.result)
  | BanUser(params) -> ((nil : list(operation)), banUser(self, params.player))
  | UnBanUser(params) -> ((nil : list(operation)), unbanUser(self, params.player))
  end