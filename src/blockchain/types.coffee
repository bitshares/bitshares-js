# sync with blockchain operations.hpp
types = module.exports
# lookup_type_id is a better name for type_id
types.type_id = (array, name) ->
    for i in [0...array.length] by 1
        if array[i] is name
            return i

operation = types.operation = []
operation[0] = "null_op_type"

# balance operations
operation[1]="withdraw_op_type"
operation[2]="deposit_op_type"

# account operations
operation[3]="register_account_op_type"
operation[4]="update_account_op_type"
operation[5]="withdraw_pay_op_type"

# asset operations"
operation[6]="create_asset_op_type"
operation[7]="update_asset_op_type"
operation[8]="issue_asset_op_type"

# delegate operations"
operation[9]="fire_delegate_op_type"

# proposal operations"
operation[10]="submit_proposal_op_type"
operation[11]="vote_proposal_op_type"

# market operations"
operation[12]="bid_op_type"
operation[13]="ask_op_type"
operation[14]="short_op_type"
operation[15]="cover_op_type"
operation[16]="add_collateral_op_type"
operation[17]="remove_collateral_op_type"
operation[18]="define_delegate_slate_op_type"
operation[19]="update_feed_op_type"
operation[21]="burn_op_type"
operation[22]="link_account_op_type"
operation[23]="withdraw_all_op_type"
operation[24]="release_escrow_op_type"

withdraw = types.withdraw = []
withdraw[0]="withdraw_null_type"
withdraw[1]="withdraw_signature_type"
withdraw[2]="withdraw_multi_sig_type"
withdraw[3]="withdraw_password_type"
withdraw[4]="withdraw_option_type"
withdraw[5]="withdraw_escrow_type"
withdraw[6]="withdraw_vesting_type"

#memo = types.memo = []
#memo[0]="from_memo"
#memo[1]="to_memo"