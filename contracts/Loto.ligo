type player is record
  addr : address;
  number : nat;
end;

type state is record
  initialized : bool;
  minAmount : tez;
  creator : address;
  players : set(player);
  bannedUsers: set(address);
end;

type betParams is record
  number : nat;
end;

type launchLotoParams is record
  result : nat;
end;

type banParams is record
  player : address;
end;

type entryAction is
  | Initialize of unit
  | Fund of unit
  | LaunchLoto of launchLotoParams
  | Bet of betParams
  | BanUser of banParams
  | UnBanUser of banParams

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
    self.minAmount := 1tez;
} with (self);

function bet (const self : state; const num : nat) : (state) is block {
    cAssert(self.bannedUsers contains Tezos.sender, "banned user");
    cAssert(Tezos.amount >= self.minAmount, "Tezos.amount = self.minAmount");
    cAssert(((num > 0n) and (num <= 1000n)), "(number > 0n) and (number <= 1000n)");
    const better : player = record[addr=Tezos.sender;number=num];
    const players : set(player) = self.players;
    self.players := Set.add(better, self.players);
} with (self);

function fund(const self : state) : (state) is block {
    skip
} with (self);

function launchLoto(const self : state; const result : nat) : (list(operation) * state) is
  block {
    cAssert(Tezos.sender = self.creator, "Tezos.sender = self.creator");
    cAssert((Set.size(self.players) > 0n), "size(self.players) > 0n");
    const winners : set (address) = set [];
    const ops : list(operation) = nil;
    const final_ops : list(operation) = nil;
    for el in set self.players block {
      if(el.number = result) then block {
        const winner_update : set(address) =  Set.add(el.addr, winners);
        winners := winner_update;
      } else skip;
    };
    for el in set self.players block {
      if(el.number = result) then block {
        const receiver : contract (unit) =
          case (Tezos.get_contract_opt(el.addr): option(contract(unit))) of
            Some (contract) -> contract
          | None -> (failwith ("Not a contract") : (contract(unit)))
          end;
        const op0 : operation = transaction(unit, (Tezos.balance/(Set.size(winners))), receiver);
        const final_ops : list(operation) = op0 # ops;
        ops := final_ops; 
      } else skip;
    };
    self.players := (Set.empty : set(player));
} with (ops, self);

function main (const action : entryAction; const self : state) : (list(operation) * state) is
  block {
    skip
  } with case action of
  | Initialize -> ((nil : list(operation)), init(self))
  | Fund -> ((nil : list(operation)), fund(self))
  | Bet(params) -> ((nil : list(operation)), bet(self, params.number))
  | LaunchLoto(params) -> launchLoto(self, params.result)
  | BanUser(params) -> ((nil : list(operation)), banUser(self, params.player))
  | UnBanUser(params) -> ((nil : list(operation)), unbanUser(self, params.player))
  end