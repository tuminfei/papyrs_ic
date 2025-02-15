import Array "mo:base/Array";
import Error "mo:base/Error";
import HashMap "mo:base/HashMap";
import Iter "mo:base/Iter";
import Option "mo:base/Option";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Text "mo:base/Text";

import Types "../types/types";
import CanisterUtils "../utils/canister.utils";
import Utils "../utils/utils";
import BucketTypes "./bucket.types";

module {
  private type UserId = Types.UserId;

  private type Bucket = BucketTypes.Bucket;

  public class BucketStore() {
    private var buckets : HashMap.HashMap<UserId, Bucket> = HashMap.HashMap<UserId, Bucket>(
      10,
      Utils.isPrincipalEqual,
      Principal.hash
    );

    private let canisterUtils : CanisterUtils.CanisterUtils = CanisterUtils.CanisterUtils();

    public func init(
      manager : Principal,
      user : UserId,
      initNewBucket : (manager : Principal, user : UserId) -> async (Principal)
    ) : async (Result.Result<Bucket, Text>) {
      let result : Result.Result<?Bucket, Text> = getBucket(user);

      switch (result) {
        case (#err error) {
          return #err error;
        };
        case (#ok bucket) {
          switch (bucket) {
            case (?bucket) {
              return #ok bucket;
            };
            case null {
              return #err "Unkown user.";
            };
          };
        };
      };
    };

    private func initBucket(
      manager : Principal,
      user : UserId,
      initNewBucket : (manager : Principal, user : UserId) -> async (Principal)
    ) : async (Result.Result<Bucket, Text>) {
      initEmptyBucket(user);

      let newBucketResult : Result.Result<Bucket, Text> = await createBucket(
        manager,
        user,
        initNewBucket
      );

      return newBucketResult;
    };

    // We add an entry in the list of bucket to know that we are creating a bucket for the user
    // In the frontend, if we get an entry without bucket, we poll until we get it
    // Doing so we aim to avoid issue if the user refresh is browser, for example, while the creation of the bucket is on going (can least up to 30s)
    private func initEmptyBucket(user : UserId) {
      let newDataBucket : BucketTypes.Bucket = {
        bucketId = null;
        owner = user;
      };

      buckets.put(user, newDataBucket);
    };

    private func createBucket(
      manager : Principal,
      user : UserId,
      initNewBucket : (manager : Principal, user : UserId) -> async (Principal)
    ) : async (Result.Result<Bucket, Text>) {
      try {
        let newBucketId : Principal = await initNewBucket(manager, user);

        let newDataBucket : BucketTypes.Bucket = {
          bucketId = ?newBucketId;
          owner = user;
        };

        buckets.put(user, newDataBucket);

        return #ok newDataBucket;
      } catch (error) {
        // If it fails, remove the pending empty bucket entry from the list
        buckets.delete(user);

        return #err("Cannot create bucket." # Error.message(error));
      };
    };

    public func getBucket(user : UserId) : Result.Result<?Bucket, Text> {
      let bucket : ?Bucket = buckets.get(user);

      switch bucket {
        case (?{owner}) {
          if (Utils.isPrincipalEqual(user, owner)) {
            return #ok bucket;
          };
        };
        case null {
          return #ok null;
        };
      };

      return #err "User does not have the permission for the bucket.";
    };

    public func deleteBucket(user : UserId) : async (Result.Result<?Bucket, Text>) {
      let bucket : Result.Result<?Bucket, Text> = getBucket(user);

      switch (bucket) {
        case (#err error) {
          return #err error;
        };
        case (#ok bucket) {
          switch (bucket) {
            case (?{bucketId}) {
              await canisterUtils.deleteCanister(bucketId);

              buckets.delete(user);
            };
            case null {};
          };

          return #ok bucket;
        };
      };
    };

    public func entries() : [Bucket] {
      let entries : Iter.Iter<(UserId, Bucket)> = buckets.entries();
      let values : Iter.Iter<Bucket> = Iter.map(
        entries,
        func((key : UserId, value : Bucket)) : Bucket {
          {
            bucketId = value.bucketId;
            owner = value.owner;
          };
        }
      );
      return Iter.toArray(values);
    };

    /**
     * Does a bucket id exists? - i.e. not a bucket for a user but is a canister id linked to any user bucket?
     */
    public func exists(canisterId : Principal) : (Bool) {
      let entries : Iter.Iter<(UserId, Bucket)> = buckets.entries();
      let values : Iter.Iter<(UserId, Bucket)> = Iter.filter(
        entries,
        func((key : UserId, {bucketId} : Bucket)) : Bool {
          switch (bucketId) {
            case null {
              return false;
            };
            case (?bucketId) {
              return bucketId == canisterId;
            };
          };
        }
      );

      return Iter.size(values) > 0;
    };

    public func preupgrade() : HashMap.HashMap<UserId, Bucket> {
      return buckets;
    };

    public func postupgrade(stableBuckets : [(UserId, Bucket)]) {
      buckets := HashMap.fromIter<UserId, Bucket>(
        stableBuckets.vals(),
        10,
        Utils.isPrincipalEqual,
        Principal.hash
      );
    };
  };

};
