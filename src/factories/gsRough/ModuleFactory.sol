// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "openzeppelin-contracts/contracts/proxy/Clones.sol";
import {Metadata} from "../../core/Metadata.sol";

// Quick and dirty module and contest factory
contract FastFactory {
    event FactoryInitialized(address[] _admins);
    event ModuleTemplateCreated(string moduleName, address moduleAddress, Metadata moduleInfo);
    event ModuleTemplateDeleted(string moduleName, address moduleAddress);
    event ContestTemplateCreated(string contestVersion, address contestAddress, Metadata contestInfo);
    event ContestTemplateDeleted(string contestVersion, address contestAddress);
    event AdminAdded(address admin);
    event AdminRemoved(address admin);
    event ModuleCloned(address moduleAddress, string moduleName, string filterTag);

    // admin => bool
    mapping(address => bool) public admins;
    // name => template address
    mapping(string => address) public moduleTemplates;
    // version => template address
    mapping(string => address) public contestTemplates;

    modifier onlyAdmin() {
        require(admins[msg.sender], "ModuleFactory: only admin");
        _;
    }

    constructor(address[] memory _admins) {
        admins[msg.sender] = true;

        address[] memory newAdmins;

        newAdmins[0] = msg.sender;

        for (uint256 i = 0; i < _admins.length; i++) {
            admins[_admins[i]] = true;

            newAdmins[i + 1] = _admins[i];
        }

        emit FactoryInitialized(newAdmins);
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

    function cloneTemplate(string memory _name, string memory _filterTag) external returns (address) {
        address template = moduleTemplates[_name];
        require(template != address(0), "Template not found");

        address module = Clones.clone(template);

        emit ModuleCloned(module, _name, _filterTag);

        return module;
    }
}
