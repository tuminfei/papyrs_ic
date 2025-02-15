import Int "mo:base/Int";
import Result "mo:base/Result";

import Utils "../utils/utils";
import InteractionTypes "./interaction.types";

module {

  type Interaction = InteractionTypes.Interaction;
  type InteractionUsers = InteractionTypes.InteractionUsers;

  public func isValidCaller({author} : Interaction, {caller; user} : InteractionUsers) : Result.Result<Text, Text> {
    if (Utils.isPrincipalEqual(caller, user)) {
      return #ok "Caller is the owner of the canister. Interaction can be edited.";
    };

    if (Utils.isPrincipalEqual(caller, author)) {
      return #ok "Caller has originally created the interaction and therefore it can be edited.";
    };

    return #err "Interaction cannot be edited the caller is neither the owner of the canister nor the author of the interaction.";
  };

};
