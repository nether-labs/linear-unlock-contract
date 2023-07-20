# Anti-Sandwich ERC-20 Extension
**Authors:** Aron Turner <[aron.turner@trueorigin.com.au](mailto:aron.turner@trueorigin.com.au)>, Dmitry Serdyuk <[dmitry.serdyuk@trueorigin.com.au](mailto:dmitry.serdyuk@trueorigin.com.au)>, Oleksandr Rybalko <[oleksandr.rybalko@trueorigin.com.au](mailto:oleksandr.rybalko@trueorigin.com.au)>

**Created:** 20/07/2023

**Version:** 0.0.1

# Abstract

The following standard attempts to address issues currently prevelent in the ecosystem at the time of this submission. It provides basic functionality to prevent MEV (Maximum extracted value) attacks known as *sandwiching* at an account and contract level.

# Motivation

Negative MEV methods such as ************sandwich************ attacks can have a detrimental effect on early-stage projects and blockchain ecosystems at large as they are not performed to the benefit of other users. This is unlike other MEV methods such as arbitraging, which can provide enhanced market efficiency and have a net-neutral effect. As such, this was the inspiration for this particular implementation, to provide a simple method to mitigate this behaviour.

# Specification

## Notes:

- The following specifications use syntax from Solidity 0.8.13 or above.

## _beforeTokenTransfer

The original implementation of this hook serves only as a template in the OpenZepplin ERC-20 library (as of 20/07/2023), found here: https://docs.openzeppelin.com/contracts/4.x/erc20. This work expands upon the utility of this function to implement the *anti-sandwich* protocol managed by a small addition of states and mappings.

### Storage/States:

```jsx
mapping(address => uint256) public tracker; // Tracks when accounts/contracts last sent/received the token

mapping(address => bool) public excused; // Accounts/contracts which are excused from this mechanism

bool blockActive = true; // Determines whether this extension is active
```

### Logic

```jsx
if (blockActive) {
	require(
			excused[from] || tracker[from] != block.timestamp,
			"Sender in same block"
	);
	
	require(
			excused[to] || tracker[to] != block.timestamp,
			"Recipient in same block"
	);

tracker[to] = tracker[from] = block.timestamp;
```

# Limitations

This implementation cannot account for all types of sandwich-based attacks, i.e. those that can be executed by bundlers ([ERC-4337](https://eips.ethereum.org/EIPS/eip-4337)). Best efforts were made to account for as much on-chain possibilities. Shown below is a diagram showing a non-exhaustive list of sandwich attacks.

![Untitled](https://github.com/trueoriginlabs/public-solidity-contracts/blob/main/docs/imgs/anti-sandwich-erc-20-extension.jpg)

If further improvements to the implementation can be made, please contact the TrueOrigin Labs team members. Corrections and additions will be recognized and will be added to the contributors list.

# Copyright

Copyright and related rights waived via CC0.

# Citation

Please cite this document as:

Aron Turner <[aron.turner@trueorigin.com.au](mailto:aron.turner@trueorigin.com.au)>, Dmitry Serdyuk <[dmitry.serdyuk@trueorigin.com.au](mailto:dmitry.serdyuk@trueorigin.com.au)>, Oleksandr Rybalko <[oleksandr.rybalko@trueorigin.com.au](mailto:oleksandr.rybalko@trueorigin.com.au)>, “Anti-Sandwich ERC-20 Extension”, July 2023, Available: [https://www.notion.so/Anti-Sandwich-ERC-20-Extension-cc1ffe07eee047c48a20182d150823c4](https://www.notion.so/Anti-Sandwich-ERC-20-Extension-cc1ffe07eee047c48a20182d150823c4?pvs=21)