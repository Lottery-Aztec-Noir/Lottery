mod types;

contract Token {
    // Libs
    use dep::std::option::Option;

    use dep::safe_math::SafeU120;
    use dep::compressed_string::FieldCompressedString;
    use dep::aztec::log::emit_unencrypted_log;

    use dep::aztec::{
        note::{
            note_getter_options::NoteGetterOptions,
            note_header::NoteHeader,
            utils as note_utils,
        },
        context::{PrivateContext, PublicContext, Context},
        hash::{compute_secret_hash},
        state_vars::{map::Map, public_state::PublicState, stable_public_state::StablePublicState,  set::Set},
        protocol_types::{
            abis::function_selector::FunctionSelector,
            address::AztecAddress
        }
    };

    // docs:start:import_authwit
    use dep::authwit::{
        auth::{
            assert_current_call_valid_authwit,
            assert_current_call_valid_authwit_public,
        },
    };
    // docs:end:import_authwit

    use crate::types::{
        transparent_note::TransparentNote,
        token_note::{TokenNote, TOKEN_NOTE_LEN},
        balances_map::BalancesMap
    };
    // docs:end::imports

    // docs:start:storage_struct
    struct Storage {
        // docs:start:storage_admin
        admin: PublicState<AztecAddress>,
        // docs:end:storage_admin
        // docs:start:storage_minters
        minters: Map<AztecAddress, PublicState<bool>>, 
        balances: BalancesMap<TokenNote>,
        total_supply: PublicState<SafeU120>, 
        pending_shields: Set<TransparentNote>, 
        public_balances: Map<AztecAddress, PublicState<SafeU120>>,
        symbol: StablePublicState<FieldCompressedString>,
        name: StablePublicState<FieldCompressedString>,
        decimals: StablePublicState<u8>,
        players_registry: Map<Field, PublicState<AztecAddress>>,
        player_registered:  Map<AztecAddress, PublicState<bool>>,
        counter: PublicState<Field>,
        winnerChosen: PublicState<bool>,
        lastTimeStamp: PublicState<SafeU120>
    }
    #[aztec(private)]
    fn constructor(admin: AztecAddress, name: str<31>, symbol: str<31>, decimals: u8) {
        let selector = FunctionSelector::from_signature("initialize((Field),(Field),(Field),u8)");
        let name_s = FieldCompressedString::from_string(name);
        let symbol_s = FieldCompressedString::from_string(symbol);
        context.call_public_function(
            context.this_address(),
            selector,
            [admin.to_field(), name_s.serialize()[0], symbol_s.serialize()[0], decimals as Field]
        );
    }

    #[aztec(public)]
    fn buy_Tickets(
        current_year: u64,
        current_month: u64,
        current_day: u64,
        birth_year: u64,
        birth_month: u64,
        birth_day: u64
    ) {
        let age = current_year - birth_year;
        assert(age >= 18, "you are not over 18");
        assert(age <= 100, "you are too old");
        assert(
            (storage.player_registered.at(context.msg_sender()).read()) == false, "you already have a ticket"
        );

        let mut counter = (storage.counter.read());
        //update mapping(counter => address) so that later the admin can choose the counter that will win the lottery.
        storage.players_registry.at(counter).write(context.msg_sender());
        storage.counter.write(counter + 1);

        //update state so check whether an address is already resgistered in a lottery or not
        storage.player_registered.at(context.msg_sender()).write(true);
    }

    #[aztec(public)]
    fn chooseWinner(randomNumber: Field) {
        //msg.sender should be the admin
        assert(context.msg_sender() == storage.admin.read(), "msg_sender not admin");
        //if the winner storage value is already filled, this function should revert. 
        assert(storage.winnerChosen.read() == false, "winner already chosen");
        //based on randomNumber that the admin uses, the winner will be automatically chosen from the players_array
        // a % b = a - (b * (a / b)) // modulo operation

        // a.div(b).mul(b)
        // let winnerIndex = randomNumber.sub(storage.counter.read().mul(randomNumber.div(storage.counter.read())));

        let winnerIndex = randomNumber - (storage.counter.read() * (randomNumber / storage.counter.read()));
        //once the winner is decided, the public state 'winner' will have an aztec address filled.
        storage.winnerChosen.write(true);
        //the winner's balance will go up.
        storage.public_balances.at(storage.players_registry.at(winnerIndex).read()).write(
            storage.public_balances.at(storage.players_registry.at(winnerIndex).read()).read().add(SafeU120::new(10000))
        );
        //once this is implemented, I should try to make a privte version of lottery.
    }

    #[aztec(public)]
    fn transfer_public(from: AztecAddress, to: AztecAddress, amount: Field, nonce: Field) {
        if (!from.eq(context.msg_sender())) {
            assert_current_call_valid_authwit_public(&mut context, from);
        } else {
            assert(nonce == 0, "invalid nonce");
        }

        let amount = SafeU120::new(amount);
        let from_balance = storage.public_balances.at(from).read().sub(amount);
        storage.public_balances.at(from).write(from_balance);

        let to_balance = storage.public_balances.at(to).read().add(amount);
        storage.public_balances.at(to).write(to_balance);
    }

    #[aztec(public)]
       internal  fn initialize(
        new_admin: AztecAddress,
        name: FieldCompressedString,
        symbol: FieldCompressedString,
        decimals: u8
    ) {
        assert(!new_admin.is_zero(), "invalid admin");
        storage.admin.write(new_admin);
        storage.minters.at(new_admin).write(true);
        storage.name.initialize(name);
        storage.symbol.initialize(symbol);
        storage.decimals.initialize(decimals);
        storage.lastTimeStamp.write(SafeU120::new(1));
    }

    unconstrained fn balance_of_public(owner: AztecAddress) -> pub u120 {
        storage.public_balances.at(owner).read().value
    }

    unconstrained fn compute_note_hash_and_nullifier(
        contract_address: AztecAddress,
        nonce: Field,
        storage_slot: Field,
        serialized_note: [Field; TOKEN_NOTE_LEN]
    ) -> pub [Field; 4] {
        let note_header = NoteHeader::new(contract_address, nonce, storage_slot);
        if (storage_slot == storage.pending_shields.get_storage_slot()) {
            note_utils::compute_note_hash_and_nullifier(
                TransparentNote::deserialize_content,
                note_header,
                serialized_note
            )
        } else {
            note_utils::compute_note_hash_and_nullifier(TokenNote::deserialize_content, note_header, serialized_note)
        }
    }
}

