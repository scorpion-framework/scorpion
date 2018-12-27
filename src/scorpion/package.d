module scorpion;

public import lighttp : Request, Response, StatusCodes, Resource, CachedResource;

public import scorpion.component : Component, Init;
public import scorpion.config : Value, Configuration, LanguageConfiguration, ProfilesConfiguration;
public import scorpion.controller : Controller, Path, Get, Post, Put, Delete, Code;
public import scorpion.entity : Entity, Id, NotNull, AutoIncrement, Nullable, Bool, Byte, Short, Integer, Long;
public import scorpion.model : Model;
public import scorpion.profile : Profile;
public import scorpion.service : Service, Repository, IgnoreCase;
public import scorpion.session : Session, Authentication, Auth;
public import scorpion.validation : NotEmpty;

//TODO move somewhere else
enum Body;
