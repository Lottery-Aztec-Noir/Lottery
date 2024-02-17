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
        my_array:Map<Field, PublicState<AztecAddress>>,
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
        // let verify= is_over_18(
        //     current_year,
        //     current_month,
        //     current_day,
        //     birth_year,
        //     birth_month,
        //     birth_day
        // );
        let age= current_year - birth_year;
        // assert(age < 18, "you are not over 18");
        assert(age >= 18, "you are not over 18");
        //WHERE 10000 is the ticket price
        let amount = SafeU120::new(10000);

        //cheek if user has minted before// you only get one ticket
        if ((storage.public_balances.at(context.msg_sender()).read().value) > 10000) {
            assert(false, "you already have a ticket");
        }
        let new_balance = storage.public_balances.at(context.msg_sender()).read().add(amount);
        let supply = storage.total_supply.read().add(amount);

        storage.public_balances.at(context.msg_sender()).write(new_balance);
        storage.total_supply.write(supply);
    }

    #[aztec(public)]
    //blocktimestamp will be passed with ethers.js in frontend
fn enter_lottery(somehash: u64) {
        if (storage.public_balances.at(context.msg_sender()).read().value < 10000) {
            assert(false, "you need to buy a ticket to enter the lottery");
        }
        //enter the lottery
        let mut valueIndex= 0;
        storage.my_array.at(valueIndex).write(context.msg_sender());
        valueIndex.add(1);
        //seding money to our lottery contract
        let selector = FunctionSelector::from_signature("transfer_public((Field),(Field),(Field),(Field))");
        let from = context.msg_sender();
        let to = context.this_address();
        context.call_public_function(
            context.this_address(),
            selector,
            [from.to_field(), to.to_field(), 10000 as Field, 1 as Field]
        );
        // implementing the lottery logic
        // block.timeStamp not implemted, lastblockTimeStamp not implemented 
        // interval =30;
        if (storage.public_balances.at(from).read().value > 10000) {
            //somehash not yet implemented can  wrap my head around it
            let winnerIndex= somehash % (valueIndex as u64);
            let winner = storage.my_array.at((winnerIndex as Field)).read();
            let selector = FunctionSelector::from_signature("transfer_public((Field),(Field),(Field),(Field))");
            let from = context.this_address();
            let to = winner;
            context.call_public_function(
                context.this_address(),
                selector,
                [
                from.to_field(), to.to_field(), storage.public_balances.at(from).read().value as Field, 1 as Field
            ]
            );
            emit_unencrypted_log(&mut context, winnerIndex);
            emit_unencrypted_log(&mut context, winner);
        }
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

// aztec-cli deploy LotteryContract-Token.json --args 0x2488662921002158513f0ff3fcd8b04e9281e0adbe1255dce909b51e0e7d3efc token sigh 8 10000
// admin: AztecAddress, name: str<31>, symbol: str<31>, decimals: u8, lastTimeStamp: u64                           

