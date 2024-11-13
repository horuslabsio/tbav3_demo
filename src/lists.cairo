#[starknet::interface]
trait IList<TContractState> {
    fn get_listings(self: @TContractState) -> Array<Listing>;
    fn get_listing(self: @TContractState, listing_id: u256) -> Listing;

    // WRITES
    fn list_tba(ref self: TContractState, tba_address: ContractAddress, lock_until: u64);
    fn sell_tba(ref self: TContractState, listing_id: u256, buyer: ContractAddress);
    //  fn upgrade_tba(ref self: TContractState, tba_address: ContractAddress)
    fn set_permission(
        ref self: TContractState,
        permissioned_addresses: Array<ContractAddress>,
        permissions: Array<bool>
    );
    fn has_permission(
        self: @TContractState, owner: ContractAddress, permissioned_address: ContractAddress
    ) -> bool;
}


#[starknet::contract]
pub mod List {
    use starknet::ContractAddress;
    use token_bound_accounts::interfaces::{
        IAccount::{IAccountDispatcher, IAccountDispatcherTrait},
    };
    use openzeppelin_token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};

    use super::IList;
    #[derive(Debug, Drop, Copy, Serde, starknet::Store)]
    pub struct Listing {
        pub listing_id: u256,
        pub seller: ContractAddress,
        pub tba_address: ContractAddress,
        pub is_active: bool
    }

    #[storage]
    struct Storage {
        listing_count: u256, // total number of listings
        listings: LegacyMap<u256, Listing>, // <listing_id, Listing>
    }

    const REGISTRY_CLASS_HASH: felt252 =
        0x46163525551f5a50ed027548e86e1ad023c44e0eeb0733f0dab2fb1fdc31ed0;

    impl ListImpl of IList<ContractState> {
        // function illustrate how to
        fn list_tba(ref self: TContractState, tba_address: ContractAddress, lock_until: u64) {
            let caller = get_caller_address();

            let account_dispatcher = IAccountDispatcher { contract_address: tba_address };
            let (owner, token, _) = account_dispatcher.token();

            // has permission to list
            let has_permission = account_dispatcher.has_permission(onwer, caller);
            assert(!has_permission, "Caller Not Permitted");

            let (is_locked, _time_remaining) = account_dispatcher.is_locked();
            assert(!is_locked, "Account is Locked");

            // lock for certain days
            account_dispatcher.lock(lock_until)
            let listing_count = self.listing_count.read();
            let listing_id = listing_count + 1;

            let listing = Listing {
                listing_id: listing_id, seller: caller, tba_address: tba_address, is_active: true
            };

            self.listings.write(listing_id, listing);
            self.listing_count.write(listing_id);
        }
        fn get_listings(self: @ContractState) -> Array<Listing> {
            let listing_count = self.listing_count.read();
            let mut i: u256 = 1;

            let mut listings: Array<Listing> = ArrayTrait::new();

            loop {
                if i > listing_count {
                    break;
                }

                let listing = self.listings.read(i);
                listings.append(listing);

                i += 1;
            };

            listings
        }

        fn get_listing(self: @ContractState, listing_id: u256) -> Listing {
            self.listings.read(listing_id)
        }

        fn sell_tba(self: @ContractState, listing_id: u256, buyer: ContractAddress) {
            let listing = self.get_listing(listing_id);

            let account_dispatcher = IAccountDispatcher { contract_address: listing.tba_address };

            let (token_contract_address, token, _) = account_dispatcher.token();

            // has permission to list to sell
            let has_permission = account_dispatcher.has_permission(token_contract_address, caller);
            assert(!has_permission, "Caller Not Permitted");

            // Create ERC20 dispatcher to interact with the token contract
            let token_dispatcher = IERC20Dispatcher { contract_address: token };

            let mut calldata = ArrayTrait::new();
            caller.serialize(ref calldata);
            buyer.serialize(ref calldata);
            token_id.serialize(ref calldata);

            // check for valid signer on caller
            let is_valid_signer = account_dispatcher.is_valid_signer(caller);
            assert(!is_valid_signer, "Not a Valid Signer");

            let call = Call {
                to: token_contract_address,
                selector: selector!("transfer_from"),
                calldata: ArrayTrait::span(@calldata)
            };

            // Transfer TBA to another owner  via execute component
            account_dispatcher.execute(array![call]);

            // Transfer TBA ERC20 token to the new owner.
            token_dispatcher.transfer_from(caller, buyer, token_id);
        }

        // fn upgrade_tba(ref self: TContractState, tba_address: ContractAddress) {

        // }

        fn set_permission(
            ref self: TContractState,
            permissioned_addresses: Array<ContractAddress>,
            permissions: Array<bool>,
            tba_address: ContractAddress,
        ) {
            let account_dispatcher = IAccountDispatcher { contract_address: tba_address };

            account_dispatcher.set_permission(permissioned_addresses, permissions);
        }
        fn has_permission(
            self: TContractState,
            owner: ContractAddress,
            permissioned_address: ContractAddress,
            tba_address: ContractAddress,
        ) -> bool {
            let account_dispatcher = IAccountDispatcher { contract_address: tba_address };

            account_dispatcher.has_permission(owner, permissioned_address);
        }
    }
}
