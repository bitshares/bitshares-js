# sync with blockchain operations.hpp
module.exports = [
    "null_op_type"

    # balance operations
    "withdraw_op_type"
    "deposit_op_type"

    # account operations
    "register_account_op_type"
    "update_account_op_type"
    "withdraw_pay_op_type"

    # asset operations"
    "create_asset_op_type"
    "update_asset_op_type"
    "issue_asset_op_type"

    # delegate operations"
    "fire_delegate_op_type"

    # proposal operations"
    "submit_proposal_op_type"
    "vote_proposal_op_type"

    # market operations"
    "bid_op_type"
    "ask_op_type"
    "short_op_type"
    "cover_op_type"
    "add_collateral_op_type"
    "remove_collateral_op_type"
    "define_delegate_slate_op_type"
    "update_feed_op_type"
    "burn_op_type"
    "link_account_op_type"
    "withdraw_all_op_type"
    "release_escrow_op_type"
]
