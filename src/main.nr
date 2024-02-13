mod types;

contract Token {
    // Libs
    use dep::std::option::Option;

    use dep::safe_math::SafeU120;
    use dep::compressed_string::FieldCompressedString;

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
        // my_arrays:PublicState<[AztecAddress; 100]>
    }
    #[aztec(private)]
    fn constructor(admin: AztecAddress, name: str<31>, symbol: str<31>, decimals: u8, ticket_price: SafeU120) {
        let selector = FunctionSelector::from_signature("_initialize((Field),(Field),(Field),u8");
        let name_s = FieldCompressedString::from_string(name);
        let symbol_s = FieldCompressedString::from_string(symbol);
        context.call_public_function(
            context.this_address(),
            selector,
            [admin.to_field(), name_s.serialize()[0], symbol_s.serialize()[0], decimals as Field]
        );
    }

    #[aztec(public)]
 //buy ticket=>> minting a token to enter the lottery
 //amount is fixed ticket price 
 //inputs is user age verifcation proff
    fn buy_Tickets(
        current_year: u64,
        current_month: u64,
        current_day: u64,
        birth_year: u64,
        birth_month: u64,
        birth_day: u64
    ) {
        let verify= is_over_18(
            current_year,
            current_month,
            current_day,
            birth_year,
            birth_month,
            birth_day
        );
        assert(!verify, "you are not over 18");
        //WHERE 10000 is the ticket price
        let amount = SafeU120::new(10000);

        //cheek if user has minted before// you only get one ticket
        if ((storage.public_balances.at(context.msg_sender()).read().value) > 0) {
            assert(false, "you already have a ticket");
        }
        let new_balance = storage.public_balances.at(context.msg_sender()).read().add(amount);
        let supply = storage.total_supply.read().add(amount);

        storage.public_balances.at(context.msg_sender()).write(new_balance);
        storage.total_supply.write(supply);
    }

    #[aztec(public)]
fn enter_lottery() {
        if (storage.public_balances.at(context.msg_sender()).read().value < 10000) {
            assert(false, "you need to buy a ticket to enter the lottery");
        }
        //enter the lottery
        let mut value= 0;
        storage.my_array.at(value).write(context.msg_sender());
        value.add(1);
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
   internal  fn _initialize(
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
        // docs:start:initialize_decimals
        storage.decimals.initialize(decimals);
        // docs:end:initialize_decimals
    }

    unconstrained fn is_over_18(
        current_year: u64,
        current_month: u64,
        current_day: u64,
        birth_year: u64,
        birth_month: u64,
        birth_day: u64
    ) -> pub bool {
        // Compute the difference in years
        let mut years_since_birth = current_year.sub(birth_year);

        // Check if the current month is earlier than the birth month
        // or if the current month is the same as the birth month but the current day is earlier
        if (current_month < birth_month) {
            // If so, subtract one from the calculated years because the person hasn't had their birthday yet this year
            years_since_birth  -=   1;
        }

        // Return true if age is greater than   18
        years_since_birth > 18
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

