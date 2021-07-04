type game is record
  player : address;
  bet : nat;
  houseCards : map(nat, nat);
  playerCards : map(nat, nat);
  state : nat;
  cardsDealt : nat;
  playerScore: nat;
end;

// Game State
// | Ongoing : 0
// | Player : 1
// | Tie : 2
// | House : 3

type state is record
  minBet : nat;
  maxBet : nat;
  blackjack : nat;
  creator: address;
  games : map(address, game);
  bannedUsers: set(address);
end;

type launchBJParams is record
  player : address;
  result1 : nat;
  result2 : nat;
  result3 : nat;
end;

type hitParams is record
  player : address;
  result : nat;
end;

type standParams is record
  player : address;
  result1 : nat;
  result2 : nat;
  result3 : nat;
end;

type banParams is record
  player : address;
end;

type entryAction is
  | LaunchBJ of launchBJParams
  | Stand of standParams
  | Hit of hitParams
  | Bet of unit
  | Fund of unit
  | BanUser of banParams
  | UnBanUser of banParams

const bj_Bet_0 : game = record [ 
  player = ("tz1burnburnburnburnburnburnburjAYjjX" : address);
  bet = 0n;
  houseCards = map[0n->0n];
  playerCards = map[0n->0n];
  state = 5n;
  cardsDealt = 0n;
  playerScore = 0n];

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

function bet(var self : state) : (state) is block {
    cAssert(not(self.bannedUsers contains Tezos.sender), "banned user");
    cAssert((Tezos.amount/1mutez) >= self.minBet, "Tezos.amount < self.minBet");
    var _bj_game : game := (case self.games[Tezos.sender] of | None -> bj_Bet_0 | Some(x) -> x end);
    cAssert(_bj_game.state =/= 0n, "_bj_game.state = 0n");
    self.games[Tezos.sender] := record [
        player=Tezos.sender;
        bet=(Tezos.amount / 1mutez);
        houseCards = map[0n->0n];
        playerCards = map[0n->0n];
        state=5n;
        cardsDealt=0n;
        playerScore=0n;
    ];
} with (self);

function fund(var self : state) : (state) is block {
    skip
} with (self);

function deck_deal (const result : nat) : (nat) is
  block {
    skip
  } with (result);

function deck_valueOf (const card : nat; const isBigAce : bool) : (nat) is
  block {
    var value : nat := (card mod 13n);
    var resultVal : nat := ((card mod 13n)+1n);
    if ((value = 9n) or (value = 10n) or (value = 11n) or (value = 12n)) then block {
      resultVal := 10n;
    } else block {
        skip;
    };
    if ((value = 0n) and isBigAce) then block {
        resultVal := 11n;
    } else block {
        skip
    };
  } with (resultVal);

function deck_isAce (const card : nat) : (bool) is
  block {
    skip
  } with ((card mod 13n) = 0n);

function deck_isTen (const card : nat) : (bool) is
  block {
    skip
  } with (((card mod 13n) = 9n) or ((card mod 13n) = 10n) or ((card mod 13n) = 11n) or ((card mod 13n) = 12n));

function calculateScore (const cards : map(nat, nat)) : ((nat * nat)) is
  block {
    var score : nat := 0n;
    var scoreBig : nat := 0n;
    var _bigAceUsed : bool := False;
    var _i : nat := 0n;
    while (_i < Map.size(cards)) block {
      const card : nat = (case cards[_i] of | None -> 0n | Some(x) -> x end);
      if (deck_isAce(card) and not (_bigAceUsed)) then block {
        scoreBig := (scoreBig + deck_valueOf(card, True));
        _bigAceUsed := True;
      } else block {
        scoreBig := (scoreBig + deck_valueOf(card, False));
      };
      score := (score + deck_valueOf(card, False));
      _i := _i + 1n;
    };
  } with ((score, scoreBig));

function checkGameResult(var self : state; const player : address; const finishGame : bool) : (list(operation) * state) is
  block {
    var _bj_game : game := (case self.games[player] of | None -> bj_Bet_0 | Some(x) -> x end);
    const tmp_0 : (nat * nat) = calculateScore(_bj_game.houseCards);
    const houseScore : nat = tmp_0.0;
    const houseScoreBig : nat = tmp_0.1;
    const tmp_1 : (nat * nat) = calculateScore(_bj_game.playerCards);
    const playerScore : nat = tmp_1.0;
    const playerScoreBig : nat = tmp_1.1;
    var op0 : operation := transaction((unit), 1mutez, (get_contract(("tz1burnburnburnburnburnburnburjAYjjX" : address)) : contract(unit)));
    _bj_game.playerScore := playerScore;
    if ((houseScoreBig = self.blackjack) or (houseScore = self.blackjack)) then block {
      if ((playerScore = self.blackjack) or (playerScoreBig = self.blackjack)) then block {
        // TIE
        op0 := transaction((unit), (_bj_game.bet * 1mutez), (get_contract(player) : contract(unit)));
        _bj_game.state := 2n;
      } else block {
        // HOUSE WON
        _bj_game.state := 3n;
      };
    } else block {
      if ((playerScore = self.blackjack) or (playerScoreBig = self.blackjack)) then block {
        // PLAYER WON
        if ((size(_bj_game.playerCards) = 2n) and (deck_isTen((case _bj_game.playerCards[0n] of | None -> 0n | Some(x) -> x end)) or deck_isTen((case _bj_game.playerCards[1n] of | None -> 0n | Some(x) -> x end)))) then block {
          // S'il a un 10 + AS on le récompense à x2.5
          op0 := transaction((unit), (((_bj_game.bet * 5n) / 2n) * 1mutez), (get_contract(player) : contract(unit)));
        } else block {
          // Sinon just x2
          op0 := transaction((unit), ((_bj_game.bet * 2n) * 1mutez), (get_contract(player) : contract(unit)));
        };
        _bj_game.state := 1n;
      } else block {
        if (playerScore > self.blackjack) then block {
          // HOUSE WON
          _bj_game.state := 3n;
        } else block {
          skip
        };
        if (finishGame) then block {
            var playerShortage : nat := 0n;
            var houseShortage : nat := 0n;
            if (playerScoreBig > self.blackjack) then block {
                if (playerScore > self.blackjack) then block {
                  
						        // HOUSE WON
                    _bj_game.state := 3n;
                    //failwith("return");
                } else block {
                    playerShortage := abs(self.blackjack - playerScore);
                };
            } else block {
                playerShortage := abs(self.blackjack - playerScoreBig);
            };
            if (houseScoreBig > self.blackjack) then block {
                if (houseScore > self.blackjack) then block {
						        // PLAYER WON
                    op0 := transaction((unit), ((_bj_game.bet * 2n) * 1mutez), (get_contract(player) : contract(unit)));
                    _bj_game.state := 1n;
                    //failwith("return");
                } else block {
                    houseShortage := abs(self.blackjack - houseScore);
                };
            } else block {
                houseShortage := abs(self.blackjack - houseScoreBig);
            };
            if (houseShortage = playerShortage) then block {
                // TIE
                op0 := transaction((unit), (_bj_game.bet * 1mutez), (get_contract(player) : contract(unit)));
                _bj_game.state := 2n;
            } else block {
                if (houseShortage > playerShortage) then block {
                    // PLAYER WON
                    op0 := transaction((unit), ((_bj_game.bet * 2n) * 1mutez), (get_contract(player) : contract(unit)));
                    _bj_game.state := 1n;
                } else block {
                    _bj_game.state := 3n;
                };
            };
        } else block {
          skip
        };
      };
    };
    self.games[player] := _bj_game;
  } with (list [op0], self);

function launchBJ(var self : state; const player : address; const result1 : nat; const result2 : nat; const result3 : nat) : (list(operation) * state) is block {
    cAssert(Tezos.sender = self.creator, "Tezos.sender = self.creator");
    var _bj_game : game := (case self.games[player] of | None -> bj_Bet_0 | Some(x) -> x end);
    var houseCards : map(nat, nat) := map end;
    var playerCards : map(nat, nat) := map end;
    playerCards[0n] := result1;
    houseCards[0n] := result2;
    playerCards[1n] := result3;
    self.games[player] := record [
        player=player;
        bet=_bj_game.bet;
        houseCards = houseCards;
        playerCards = playerCards;
        state=0n;
        cardsDealt=3n;
        playerScore=0n;
    ];
    var tmp_0 : (list(operation) * state) := checkGameResult(self, player, False);
    const opList : list(operation) = tmp_0.0;
    self := tmp_0.1;
} with (opList, self);

function hit (var self : state; const player : address; const result : nat) : (list(operation) * state) is
  block {
    var _bj_game : game := (case self.games[player] of | None -> bj_Bet_0 | Some(x) -> x end);
    cAssert(_bj_game.state = 0n, "_bj_game.state =/= 0n");
    const nextCard : nat = _bj_game.cardsDealt;
    _bj_game.playerCards[size(_bj_game.playerCards)] := result;
    _bj_game.cardsDealt := (nextCard + 1n);
    self.games[player] := _bj_game;
    const tmp_1 : (list(operation) * state) = checkGameResult(self, player, False);
    var listOp : list(operation) := tmp_1.0;
    var store : state := tmp_1.1;
  } with (listOp, store);

function stand (var self : state; const player : address; const result : nat; const result2 : nat; const result3 : nat) : (list(operation) * state) is
  block {
    var _bj_game : game := (case self.games[player] of | None -> bj_Bet_0 | Some(x) -> x end);
    cAssert(_bj_game.state = 0n, "_bj_game.state =/= 0n");
    const tmp_0 : (nat * nat) = calculateScore(_bj_game.houseCards);
    var _houseScoreBig : nat := tmp_0.1;
    if(_houseScoreBig < 17n) then block {
      const nextCard : nat = _bj_game.cardsDealt;
      const newCard : nat = result;
      _bj_game.houseCards[size(_bj_game.houseCards)] := newCard;
      _bj_game.cardsDealt := (nextCard + 1n);
      _houseScoreBig := (_houseScoreBig + deck_valueOf(newCard, True));
    } else block {
      skip
    };
    if(_houseScoreBig < 17n) then block {
      const nextCard : nat = _bj_game.cardsDealt;
      const newCard : nat = result2;
      _bj_game.houseCards[size(_bj_game.houseCards)] := newCard;
      _bj_game.cardsDealt := (nextCard + 1n);
      _houseScoreBig := (_houseScoreBig + deck_valueOf(newCard, True));
    } else block {
      skip
    };
    if(_houseScoreBig < 17n) then block {
      const nextCard : nat = _bj_game.cardsDealt;
      const newCard : nat = result3;
      _bj_game.houseCards[size(_bj_game.houseCards)] := newCard;
      _bj_game.cardsDealt := (nextCard + 1n);
      _houseScoreBig := (_houseScoreBig + deck_valueOf(newCard, True));
    } else block {
      skip
    };
    self.games[player] := _bj_game;
    const tmp_2 : (list(operation) * state) = checkGameResult(self, player, True);
    var opList : list(operation) := tmp_2.0;
    var store : state := tmp_2.1;
  } with (opList, store);


function main (const action : entryAction; const self : state) : (list(operation) * state) is
  block {
    skip
  } with case action of
  | LaunchBJ(params) -> launchBJ(self, params.player, params.result1, params.result2, params.result3)
  | Stand(params) -> stand(self, params.player, params.result1, params.result2, params.result3)
  | Hit(params) -> hit(self, params.player, params.result)
  | Bet -> ((nil : list(operation)), bet(self))
  | Fund -> ((nil : list(operation)), fund(self))
  | BanUser(params) -> ((nil : list(operation)), banUser(self, params.player))
  | UnBanUser(params) -> ((nil : list(operation)), unbanUser(self, params.player))
end