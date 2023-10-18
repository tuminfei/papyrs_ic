import Principal "mo:base/Principal";

import IC "../types/ic.types";
import Types "../types/types";

module {
  public type BucketId = IC.canister_id;

  public type Bucket = {
    bucketId : ?BucketId;
    owner : Types.UserId;
  };
};
