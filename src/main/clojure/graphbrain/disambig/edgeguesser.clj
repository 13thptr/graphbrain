(ns graphbrain.disambig.edgeguesser
  (:require [graphbrain.hg.ops :as hgops]
            [graphbrain.hg.symbol :as sym]
            [graphbrain.disambig.entityguesser :as eg]))

(defn eid->guess-eid
  [hg eid text ctxt ctxts]
  #_(let [ids (id/id->ids eid)
        guess (eg/guess-eid gbdb (second ids) text nil ctxt ctxts)]
    (if (id/eid? guess) guess
        (id/name+ids->eid
         (first ids)
         (second ids)
         (map #(eg/guess-eid gbdb % text nil ctxt ctxts) (drop 2 ids))))))

(defn guess
  [hg id text ctxt ctxts]
  #_(case (id/id->type id)
    :entity (eg/guess-eid gbdb id text nil ctxt ctxts)
    :text (:id (gbdb/putv!
                gbdb
                (text/pseudo->vertex id)
                ctxt))
    :edge (if (id/eid? id)
            (eid->guess-eid gbdb id text ctxt ctxts)
            (id/ids->id (map #(guess gbdb % text ctxt ctxts) (id/id->ids id))))
    id))
