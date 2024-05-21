// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "openzeppelin-contracts/contracts/proxy/Clones.sol";
import {Metadata} from "../../core/Metadata.sol";

import {Contest} from "../../Contest.sol";

import {IModule} from "../../interfaces/IModule.sol";

// Quick and dirty module and contest factory for rapid development of GS Voting
contract FastFactory {
    event FactoryInitialized(address admin);
    event ModuleTemplateCreated(string moduleName, address moduleAddress, Metadata moduleInfo);
    event ModuleTemplateDeleted(string moduleName, address moduleAddress);
    event ContestTemplateCreated(string contestVersion, address contestAddress, Metadata contestInfo);
    event ContestTemplateDeleted(string contestVersion, address contestAddress);
    event AdminAdded(address admin);
    event AdminRemoved(address admin);
    event ModuleCloned(address moduleAddress, string moduleName, string filterTag);
    event ContestBuilt(
        string votesModule,
        string pointsModule,
        string choicesModule,
        string executionModule,
        address contestAddress,
        string contestVersion,
        string filterTag
    );

    // admin => bool
    mapping(address => bool) public admins;
    // name => template address
    mapping(string => address) public moduleTemplates;
    // version => template address
    mapping(string => address) public contestTemplates;
    // tagId => bool
    mapping(string => bool) public filterTags;

    modifier onlyAdmin() {
        require(admins[msg.sender], "ModuleFactory: only admin");
        _;
    }

    constructor(address _admin) {
        admins[_admin] = true;

        emit FactoryInitialized(_admin);
    }

    function setModuleTemplate(string memory _name, address _template, Metadata memory _templateInfo)
        external
        onlyAdmin
    {
        require(moduleTemplates[_name] == address(0), "Template already exists");
        moduleTemplates[_name] = _template;

        emit ModuleTemplateCreated(_name, _template, _templateInfo);
    }

    function removeModuleTemplate(string memory _name) external onlyAdmin {
        require(moduleTemplates[_name] != address(0), "Template not found");
        delete moduleTemplates[_name];

        emit ModuleTemplateDeleted(_name, moduleTemplates[_name]);
    }

    function setContestTemplate(string memory _version, address _template, Metadata memory _templateInfo)
        external
        onlyAdmin
    {
        require(contestTemplates[_version] == address(0), "Template already exists");
        contestTemplates[_version] = _template;

        emit ContestTemplateCreated(_version, _template, _templateInfo);
    }

    function removeContestTemplate(string memory _version) external onlyAdmin {
        require(contestTemplates[_version] != address(0), "Template not found");
        delete contestTemplates[_version];

        emit ContestTemplateDeleted(_version, contestTemplates[_version]);
    }

    function addAdmin(address _account) external onlyAdmin {
        admins[_account] = true;

        emit AdminAdded(_account);
    }

    function removeAdmin(address _account) external onlyAdmin {
        admins[_account] = false;

        emit AdminRemoved(_account);
    }

    function buildContest(
        bytes memory _contestInitData,
        string memory _contestVersion,
        bool _isContinuous,
        bool _isRetractable,
        string memory _filterTag
    ) external returns (address, address[4] memory moduleAddresses) {
        address contestTemplate = contestTemplates[_contestVersion];
        require(contestTemplate != address(0), "Template not found");
        require(filterTags[_filterTag] == false, "Filter tag already exists");

        Contest newContest = Contest(Clones.clone(contestTemplate));

        (string[4] memory _moduleNames, bytes[4] memory _moduleData) =
            abi.decode(_contestInitData, (string[4], bytes[4]));

        for (uint256 i = 0; i < _moduleNames.length; i++) {
            // clones the module template using clone template so we can index
            // the module address with the module name and filter tag
            moduleAddresses[i] = _cloneTemplate(_moduleNames[i], _filterTag);
            // initialize the module
            IModule module = IModule(moduleAddresses[i]);
            module.initialize(address(newContest), _moduleData[i]);
        }

        newContest.initialize(
            abi.encode(
                // votesModule
                moduleAddresses[0],
                // pointsModule
                moduleAddresses[1],
                // choicesModule
                moduleAddresses[2],
                // executionModule
                moduleAddresses[3],
                _isContinuous,
                _isRetractable
            )
        );

        filterTags[_filterTag] = true;

        emit ContestBuilt(
            _moduleNames[0],
            _moduleNames[1],
            _moduleNames[2],
            _moduleNames[3],
            address(newContest),
            _contestVersion,
            _filterTag
        );

        return (address(newContest), moduleAddresses);
    }

    function _cloneTemplate(string memory _name, string memory _filterTag) internal returns (address) {
        address template = moduleTemplates[_name];
        require(template != address(0), "Template not found");

        address module = Clones.clone(template);

        emit ModuleCloned(module, _name, _filterTag);

        return module;
    }
}
