#[starknet::interface]
trait IList<TContractState> {
    fn get_listings(self: @TContractState) -> Array<Listing>;
    fn get_listing(self: @TContractState, listing_id: u256) -> Listing;

    // WRITES
    fn list_tba(ref self: TContractState, tba_address: ContractAddress, lock_until: u64);

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

            let (is_locked, _time_remaining) = account_dispatcher.is_locked();
            assert(!is_locked, "Account is Locked");

            // lock for 30 days
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
