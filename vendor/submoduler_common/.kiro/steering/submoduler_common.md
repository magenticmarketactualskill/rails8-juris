# Submodules Guide

## Overview

The `submoduler-core-submoduler_*` gems are used by projects like active_data_flow to manage parent/child gem relationships.

All component implementations are managed in a parent has_many child hierarchy.

Parent projects use submoduler-core-submoduler_parent gem. 

Parent projects use submoduler-core-submoduler_child gem.

reference: https://github.com/magenticmarketactualskill/submoduler-core-submoduler_common.git

**Key Distinction**:

- **Parent gem example** (`submoduler-core-submoduler_parent`) - Used (by example) in **Parent gem** active_data_flow (the parent)

- **Child gem example** (`submoduler-core-submoduler_child`) - Used (by example) in - **Child gem** in active_data_flow-runtime-heartbeat (a child of parent).

**Current Structure**: All components are in `submodules/` directory as git submodules with independent repositories.
